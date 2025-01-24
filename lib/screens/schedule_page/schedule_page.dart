import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/constants/strings.dart';
import 'package:schedule_recorder/models/audio_file.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_receiver_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';
import 'package:schedule_recorder/widgets/schedule_page/audio_file_list.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

/// ロガー
final logger = Logger(
  filter: ProductionFilter(),
  output: MultiOutput([
    ConsoleOutput(),
    CustomFileOutput(),
  ]),
  printer: SimplePrinter(colors: false),
  level: Level.info,
);

/// ログファイルの出力
class CustomFileOutput extends LogOutput {
  static String? _logPath;

  static void setLogPath(String path) {
    _logPath = path;
  }

  @override
  void output(OutputEvent event) {
    if (_logPath == null) return;

    try {
      final file = File(_logPath!);
      final timestamp = DateTime.now().toIso8601String();
      final level = event.level.toString().split('.').last.toUpperCase();

      // 各ログ行にタイムスタンプとレベルを付加
      for (final line in event.lines) {
        final formattedLine = '$timestamp [$level] $line\n';
        file.writeAsStringSync(formattedLine,
            mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('ログファイルの書き込みに失敗: $e');
    }
  }
}

/// スケジュールページ
class SchedulePage extends StatefulWidget {
  final AudioRecorder recorder;
  final AudioPlayer player;
  final FileSharingService? fileSharingService;
  final FileManagementService fileManagementService;
  final String documentsPath;
  final Logger logger;

  const SchedulePage({
    super.key,
    required this.recorder,
    required this.player,
    this.fileSharingService,
    required this.fileManagementService,
    required this.documentsPath,
    required this.logger,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

/// スケジュールページの状態
class _SchedulePageState extends State<SchedulePage> {
  bool isRecording = false;
  bool isPlaying = false;
  bool isPaused = false;
  String? _recordingPath;
  bool _isInitialized = false;
  late final String _logPath;
  late final FileSharingService _fileSharingService;
  late final FileReceiverService _fileReceiverService;
  late final FileManagementService _fileManagementService;
  late final AudioService _audioService;
  List<AudioFile> _audioFiles = [];

  @override
  void initState() {
    super.initState();
    _fileSharingService =
        widget.fileSharingService ?? FileSharingService(logger: widget.logger);
    _fileReceiverService = FileReceiverService(logger: widget.logger);
    _fileManagementService = FileManagementService(
      logger: widget.logger,
      documentsPath: widget.documentsPath,
    );
    _audioService = AudioService(
      player: widget.player,
      logger: widget.logger,
    );

    _initializeLogger();
    _initializeRecorder().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // 初期化完了後にファイル受信の設定を行う
        _setupFileReceiver();
        _loadAudioFiles();
      }
      // AudioServiceのリスナーを設定（初期化時に行う）
      AudioService.setupNativeListeners(
        onInterrupted: () {
          widget.logger.i('Audio interruption detected');
          if (isRecording && !isPaused) {
            _handleRecordingInterrupted();
          }
        },
        onResumed: () {
          widget.logger.i('Audio resumption detected');
          if (isRecording && isPaused) {
            // 条件を修正
            _handleRecordingResumed();
          }
        },
      );
    }).catchError((e) {
      widget.logger.e('Recorder initialization error: $e');
    });
  }

  /// ファイル受信サービスの設定
  void _setupFileReceiver() {
    widget.logger.i('Setting up file receiver...');
    _fileReceiverService
        .handleSharedFiles(
      onAudioFileReceived: _handleReceivedAudioFile,
      onLogFileReceived: _handleReceivedLogFile,
    )
        .then((_) {
      widget.logger.i('File receiver setup completed');
    }).catchError((e) {
      widget.logger.e('File receiver setup failed: $e');
    });
  }

  /// 共有された音声ファイルをアプリのドキュメントディレクトリにコピーする
  ///
  /// [file] - コピーするファイル
  ///
  /// 戻り値: コピーされたファイルのパス
  Future<void> _handleReceivedAudioFile(File file) async {
    try {
      final newPath = await _fileReceiverService.copyFileToDocuments(
        file,
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      setState(() {
        _recordingPath = newPath;
      });
      // ファイルリストを更新
      await _loadAudioFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音声ファイルを受信しました')),
      );
    } catch (e) {
      widget.logger.e('音声ファイルの処理に失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音声ファイルの処理に失敗しました')),
      );
    }
  }

  /// 共有されたログファイルをアプリのドキュメントディレクトリにコピーする
  ///
  /// [file] - コピーするファイル
  ///
  /// 戻り値: コピーされたファイルのパス
  Future<void> _handleReceivedLogFile(File file) async {
    try {
      await _fileReceiverService.copyFileToDocuments(
        file,
        'app.log',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログファイルを受信しました')),
      );
    } catch (e) {
      widget.logger.e('ログファイルの処理に失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログファイルの処理に失敗しました')),
      );
    }
  }

  /// ログファイルの初期化
  ///
  /// 戻り値: ログファイルのパス
  Future<void> _initializeLogger() async {
    final appDir = await getApplicationDocumentsDirectory();
    _logPath = path.join(appDir.path, 'app.log');
    CustomFileOutput.setLogPath(_logPath);

    // ログファイルの初期化
    final logFile = File(_logPath);
    if (!logFile.existsSync()) {
      await logFile.create();
    }

    // 初期ログエントリを書き込む（ファイルが空の場合のみ）
    if (logFile.lengthSync() == 0) {
      widget.logger
        ..w('=== アプリケーションログ開始 ===')
        ..w('アプリケーションを起動しました')
        ..w('ログファイルパス: $_logPath');
    }
  }

  /// 録音機器の初期化
  ///
  /// 戻り値: 録音機器のパス
  Future<void> _initializeRecorder() async {
    try {
      widget.logger.i('Initializing recorder...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('マイクの権限が必要です');
      }
      widget.logger.i('Microphone permission granted');

      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/recording.m4a';
      widget.logger.i('Recording path set to: $_recordingPath');

      widget.logger.i('Recorder initialization completed successfully');
    } catch (e) {
      widget.logger.e('Recorder initialization error: $e');
      rethrow;
    }
  }

  /// 録音の開始
  ///
  /// 戻り値: 録音の開始結果
  Future<void> _startRecording() async {
    if (!_isInitialized) {
      widget.logger.w('Recorder is not initialized yet');
      return;
    }

    if (!isRecording && _recordingPath != null) {
      try {
        widget.logger.i('Starting recording...');

        // AudioServiceのリスナーを設定
        AudioService.setupNativeListeners(
          onInterrupted: () {
            widget.logger.i('Audio interruption detected');
            if (isRecording && !isPaused) {
              _handleRecordingInterrupted();
            }
          },
          onResumed: () {
            widget.logger.i('Audio resumption detected');
            if (isPaused) {
              _handleRecordingResumed();
            }
          },
        );

        // 録音開始前に状態をリセット
        if (mounted) {
          setState(() {
            isPaused = false;
          });
        }

        await widget.recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );

        // 録音開始後に状態を更新
        if (mounted) {
          setState(() {
            isRecording = true;
          });
          widget.logger.i('Recording started successfully');
        }
      } catch (e) {
        widget.logger.e('録音開始エラー: $e');
        if (mounted) {
          setState(() {
            isRecording = false;
            isPaused = false;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音の開始に失敗しました')),
          );
        }
      }
    }
  }

  Future<void> _stopRecording() async {
    if (isRecording) {
      try {
        widget.logger.i('Stopping recording...');
        await widget.recorder.stop();
        setState(() {
          isRecording = false;
          isPaused = false;
        });
        widget.logger.i('Recording stopped');
        // 録音停止後にファイルリストを更新
        await _loadAudioFiles();
      } catch (e) {
        widget.logger.e('録音停止エラー: $e');
      }
    }
  }

  /// 再生の開始
  ///
  /// 戻り値: 再生の開始結果
  Future<void> _startPlaying() async {
    if (!isPlaying && _recordingPath != null) {
      try {
        widget.logger.i('Starting playback...');
        setState(() {
          isRecording = false;
          isPaused = false;
        });

        await widget.player.setVolume(1.0);
        await widget.player.setFilePath(_recordingPath!);

        if (mounted) {
          setState(() {
            isPlaying = true;
          });
        }

        widget.player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            widget.logger.i('Playback finished');
            if (mounted) {
              setState(() {
                isPlaying = false;
              });
            }
          }
        });

        await widget.player.play();
        widget.logger.i('Playback started');
      } catch (e) {
        widget.logger.e('再生開始エラー: $e');
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
      }
    }
  }

  /// 再生の停止
  ///
  /// 戻り値: 再生の停止結果
  Future<void> _stopPlaying() async {
    if (isPlaying) {
      try {
        widget.logger.i('Stopping playback...');
        await widget.player.stop();
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
        widget.logger.i('Playback stopped');
      } catch (e) {
        widget.logger.e('再生停止エラー: $e');
      }
    }
  }

  /// 録音の中断
  ///
  /// 戻り値: 録音の中断結果
  Future<void> _handleRecordingInterrupted() async {
    widget.logger.i(
        'Recording interrupted handler called. isRecording: $isRecording, isPaused: $isPaused');
    if (isRecording && !isPaused) {
      try {
        widget.logger.i('Recording interrupted...');
        await widget.recorder.pause();
        if (mounted) {
          setState(() {
            isPaused = true;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音を一時停止しました')),
          );
        }
      } catch (e) {
        widget.logger.e('録音の一時停止に失敗しました: $e');
      }
    }
  }

  /// 録音の再開
  ///
  /// 戻り値: 録音の再開結果
  Future<void> _handleRecordingResumed() async {
    widget.logger.i(
        'Recording resumed handler called. isRecording: $isRecording, isPaused: $isPaused');
    if (isRecording && isPaused) {
      // 条件を明確化
      try {
        widget.logger.i('Resuming recording...');
        await widget.recorder.resume();
        if (mounted) {
          setState(() {
            isPaused = false;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音を再開しました')),
          );
        }
      } catch (e) {
        widget.logger.e('録音の再開に失敗しました: $e');
        if (mounted) {
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音の再開に失敗しました')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    if (isRecording) {
      widget.recorder.stop();
    }
    if (isPlaying) {
      widget.player.stop();
    }
    widget.recorder.dispose();
    widget.player.dispose();
    widget.logger.i('Recorder and Player disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Recorder'),
        actions: [
          if (_isInitialized && !isRecording)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'ファイルを共有',
              onPressed: _shareFiles,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isInitialized)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // 録音状態のラベル
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Builder(
                  builder: (context) {
                    if (isRecording && !isPaused) {
                      return Text(
                        Strings.recordingRecording,
                        style: const TextStyle(fontSize: 16),
                      );
                    } else if (isRecording && isPaused) {
                      return Text(
                        Strings.recordingPaused,
                        style: const TextStyle(fontSize: 16),
                      );
                    } else if (isPlaying) {
                      return Text(
                        Strings.recordingPlaying,
                        style: const TextStyle(fontSize: 16),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              // 録音・再生コントロール
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RecordingButtons(
                  isRecording: isRecording,
                  isPlaying: isPlaying,
                  isPaused: isPaused,
                  onStartRecording: _startRecording,
                  onStopRecording: _stopRecording,
                  onStartPlaying: _startPlaying,
                  onStopPlaying: _stopPlaying,
                  onPauseRecording: _handleRecordingInterrupted,
                  onResumeRecording: _handleRecordingResumed,
                ),
              ),
              // ファイルリスト
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AudioFileList(
                    files: _audioFiles,
                    onPlayTap: _handlePlayTap,
                    onDeleteTap: _handleDeleteTap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ファイルの共有
  ///
  /// 戻り値: ファイルの共有結果
  Future<void> _shareFiles() async {
    try {
      await _fileSharingService.shareFiles(
        context: context,
        logPath: _logPath,
      );
    } on ShareFilesException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// ファイル一覧の取得
  ///
  /// 戻り値: ファイル一覧の取得結果
  Future<void> _loadAudioFiles() async {
    try {
      final files = await _fileManagementService.getAudioFiles();
      setState(() {
        _audioFiles = files;
      });
    } catch (e) {
      widget.logger.e('ファイル一覧の取得に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Strings.errorLoadingFiles)),
        );
      }
    }
  }

  /// 再生のタップ
  ///
  /// 戻り値: 再生のタップ結果
  Future<void> _handlePlayTap(AudioFile file) async {
    try {
      await _audioService.startPlaying(file.path);
    } catch (e) {
      widget.logger.e('再生に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Strings.errorPlayingFile)),
        );
      }
    }
  }

  /// ファイルの削除
  ///
  /// 戻り値: ファイルの削除結果
  Future<void> _handleDeleteTap(AudioFile file) async {
    try {
      await _fileManagementService.deleteFile(file.path);
      await _loadAudioFiles();
    } catch (e) {
      widget.logger.e('削除に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Strings.errorDeletingFile)),
        );
      }
    }
  }
}
