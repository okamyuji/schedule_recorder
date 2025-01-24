import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_receiver_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';
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

  const SchedulePage({
    super.key,
    required this.recorder,
    required this.player,
    this.fileSharingService,
  });

  @override
  SchedulePageState createState() => SchedulePageState();
}

/// スケジュールページの状態
class SchedulePageState extends State<SchedulePage> {
  bool isRecording = false;
  bool isPlaying = false;
  bool isPaused = false;
  String? _recordingPath;
  bool _isInitialized = false;
  late final String _logPath;
  late final FileSharingService _fileSharingService;
  late final FileReceiverService _fileReceiverService;

  @override
  void initState() {
    super.initState();
    _fileSharingService =
        widget.fileSharingService ?? FileSharingService(logger: logger);
    _fileReceiverService = FileReceiverService(logger: logger);
    _initializeLogger();
    _initializeRecorder().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _setupFileReceiver();
      }
    }).catchError((e) {
      logger.e('Recorder initialization error: $e');
    });
  }

  /// ファイル受信サービスの設定
  void _setupFileReceiver() {
    _fileReceiverService.handleSharedFiles(
      onAudioFileReceived: _handleReceivedAudioFile,
      onLogFileReceived: _handleReceivedLogFile,
    );
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
        'recording.m4a',
      );
      setState(() {
        _recordingPath = newPath;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音声ファイルを受信しました')),
      );
    } catch (e) {
      logger.e('音声ファイルの処理に失敗: $e');
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
      logger.e('ログファイルの処理に失敗: $e');
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
      logger
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
      logger.i('Initializing recorder...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('マイクの権限が必要です');
      }
      logger.i('Microphone permission granted');

      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/recording.m4a';
      logger.i('Recording path set to: $_recordingPath');

      logger.i('Recorder initialization completed successfully');
    } catch (e) {
      logger.e('Recorder initialization error: $e');
      rethrow;
    }
  }

  /// 録音の開始
  ///
  /// 戻り値: 録音の開始結果
  Future<void> _startRecording() async {
    if (!_isInitialized) {
      logger.w('Recorder is not initialized yet');
      return;
    }

    if (!isRecording && _recordingPath != null) {
      try {
        logger.i('Starting recording...');

        // AudioServiceのリスナーを設定
        AudioService.setupNativeListeners(
          onInterrupted: () {
            logger.i('Audio interruption detected');
            if (isRecording && !isPaused) {
              _handleRecordingInterrupted();
            }
          },
          onResumed: () {
            logger.i('Audio resumption detected');
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
          logger.i('Recording started successfully');
        }
      } catch (e) {
        logger.e('録音開始エラー: $e');
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
        logger.i('Stopping recording...');
        await widget.recorder.stop();
        setState(() {
          isRecording = false;
          isPaused = false;
        });
        logger.i('Recording stopped');
      } catch (e) {
        logger.e('録音停止エラー: $e');
      }
    }
  }

  /// 再生の開始
  ///
  /// 戻り値: 再生の開始結果
  Future<void> _startPlaying() async {
    if (!isPlaying && _recordingPath != null) {
      try {
        logger.i('Starting playback...');
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
            logger.i('Playback finished');
            if (mounted) {
              setState(() {
                isPlaying = false;
              });
            }
          }
        });

        await widget.player.play();
        logger.i('Playback started');
      } catch (e) {
        logger.e('再生開始エラー: $e');
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
        logger.i('Stopping playback...');
        await widget.player.stop();
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
        logger.i('Playback stopped');
      } catch (e) {
        logger.e('再生停止エラー: $e');
      }
    }
  }

  /// 録音の中断
  ///
  /// 戻り値: 録音の中断結果
  Future<void> _handleRecordingInterrupted() async {
    logger.i(
        'Recording interrupted handler called. isRecording: $isRecording, isPaused: $isPaused');
    if (isRecording && !isPaused) {
      try {
        logger.i('Recording interrupted...');
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
        logger.e('録音の一時停止に失敗しました: $e');
      }
    }
  }

  /// 録音の再開
  ///
  /// 戻り値: 録音の再開結果
  Future<void> _handleRecordingResumed() async {
    if (isPaused) {
      try {
        logger.i('Resuming recording...');
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
        logger.e('録音の再開に失敗しました: $e');
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
    logger.i('Recorder and Player disposed');
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isInitialized)
              const CircularProgressIndicator()
            else ...[
              RecordingButtons(
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
              const SizedBox(height: 20),
              if (isRecording && !isPaused)
                const Text('録音中...', style: TextStyle(fontSize: 16))
              else if (isRecording && isPaused)
                const Text('録音一時停止中...', style: TextStyle(fontSize: 16))
              else if (isPlaying)
                const Text('再生中...', style: TextStyle(fontSize: 16)),
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
}
