import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/constants/schedule_page/strings.dart';
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';
import 'package:schedule_recorder/widgets/schedule_page/audio_file_list.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ロガー
final logger = Logger(
  filter: DevelopmentFilter(),
  output: MultiOutput([
    ConsoleOutput(),
    CustomFileOutput(),
  ]),
  printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart),
  level: Level.debug,
);

/// ログファイルの出力
class CustomFileOutput extends LogOutput {
  static String? _logPath;
  static final _lock = Lock();

  static void setLogPath(String path) {
    _logPath = path;
    final file = File(_logPath!);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
  }

  @override
  void output(OutputEvent event) {
    if (_logPath == null) return;

    _lock.synchronized(() {
      try {
        final file = File(_logPath!);
        final timestamp = DateTime.now().toIso8601String();
        final level = event.level.toString().split('.').last.toUpperCase();
        final message = event.lines.join('\n');
        final logEntry = '$timestamp [$level] $message\n';

        file.writeAsStringSync(logEntry, mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('ログファイルへの書き込みに失敗しました: $e');
      }
    });
  }
}

/// スケジュールページ
class SchedulePage extends ConsumerStatefulWidget {
  final AudioRecorder recorder;
  final AudioPlayer player;
  final FileSharingService? fileSharingService;
  final FileManagementService fileManagementService;
  final String documentsPath;
  final Logger logger;
  final AutoDisposeNotifierProvider<RecordingStateNotifier, RecordingState>
      recordingStateNotifier;

  const SchedulePage({
    super.key,
    required this.recorder,
    required this.player,
    this.fileSharingService,
    required this.fileManagementService,
    required this.documentsPath,
    required this.logger,
    required this.recordingStateNotifier,
  });

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

/// スケジュールページの状態
class _SchedulePageState extends ConsumerState<SchedulePage> {
  bool isRecording = false;
  bool isPlaying = false;
  bool isPaused = false;
  String? _recordingPath;
  bool _isInitialized = false;
  late final String _logPath;
  late final FileSharingService _fileSharingService;
  late final FileManagementService _fileManagementService;
  late final AudioService _audioService;
  List<AudioFile> _audioFiles = [];
  RecordState _recordState = RecordState.stop;

  @override
  void initState() {
    super.initState();
    _fileSharingService =
        widget.fileSharingService ?? FileSharingService(logger: widget.logger);
    _fileManagementService = FileManagementService(
      logger: widget.logger,
      documentsPath: widget.documentsPath,
    );
    _audioService = AudioService(
      player: widget.player,
      logger: widget.logger,
      recordingStateNotifier: ref.read(widget.recordingStateNotifier.notifier),
      recorder: widget.recorder,
      audioServiceNotifier: ref.read(audioServiceNotifierProvider.notifier),
    );

    _initializeLogger();
    _initializeRecorder().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _loadAudioFiles();
      }
      _audioService.setupNativeListeners();
    }).catchError((e) {
      widget.logger.e('Recorderの初期化に失敗しました: $e');
    });
  }

  /// ログファイルの初期化
  Future<void> _initializeLogger() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logPath = path.join(appDir.path, 'app.log');
      CustomFileOutput.setLogPath(_logPath);

      widget.logger
        ..i('=== アプリケーションログ開始 ===')
        ..i('アプリケーションを起動しました')
        ..i('ログファイルパス: $_logPath')
        ..i('アプリバージョン: ${await _getAppVersion()}')
        ..i('デバイス情報: ${await _getDeviceInfo()}');
    } catch (e) {
      debugPrint('ロガーの初期化に失敗しました: $e');
    }
  }

  /// アプリバージョンの取得
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// デバイス情報の取得
  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.systemName} ${iosInfo.systemVersion})';
      }
      return 'Unknown';
    } catch (e) {
      return 'デバイス情報の取得に失敗しました';
    }
  }

  /// 録音機器の初期化
  ///
  /// 戻り値: 録音機器のパス
  Future<void> _initializeRecorder() async {
    try {
      widget.logger.i('Recorderの初期化を開始します');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        widget.logger.e('マイクの権限が許可されていません');
        return; // 権限がない場合、早期リターン
      }
      widget.logger.i('マイクの権限が許可されました');

      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/recording.m4a';
      widget.logger.i('Recorderのパスを設定します: $_recordingPath');

      widget.logger.i('Recorderの初期化が完了しました');
    } catch (e) {
      widget.logger.e('Recorderの初期化に失敗しました: $e');
    }
  }

  /// 録音の開始
  ///
  /// 戻り値: 録音の開始結果
  Future<void> _startRecording() async {
    if (_recordState == RecordState.stop && _recordingPath != null) {
      try {
        widget.logger.i('録音を開始します');
        await _audioService.startRecording(_recordingPath!);
        setState(() {
          _recordState = RecordState.record;
        });
        widget.logger.i('録音が開始されました');
      } catch (e) {
        widget.logger.e('録音の開始に失敗しました: $e');
        setState(() {
          _recordState = RecordState.stop;
        });
        rethrow;
      }
    }
  }

  /// 録音の停止
  ///
  /// 戻り値: 録音の停止結果
  Future<void> _stopRecording() async {
    if (_recordState != RecordState.stop) {
      try {
        widget.logger.i('録音を停止します');
        await _audioService.stopRecording();
        setState(() {
          _recordState = RecordState.stop;
        });
        await _loadAudioFiles();
        widget.logger.i('録音が停止されました');
      } catch (e) {
        widget.logger.e('録音の停止に失敗しました: $e');
        rethrow;
      }
    }
  }

  /// 再生の開始
  ///
  /// 戻り値: 再生の開始結果
  Future<void> _startPlaying() async {
    if (!isPlaying && _recordingPath != null) {
      try {
        widget.logger.i('再生を開始します');
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
            widget.logger.i('再生が完了しました');
            if (mounted) {
              setState(() {
                isPlaying = false;
              });
            }
          }
        });

        await widget.player.play();
        widget.logger.i('再生が開始されました');
      } catch (e) {
        widget.logger.e('再生の開始に失敗しました: $e');
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
        widget.logger.i('再生を停止します');
        await widget.player.stop();
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
        widget.logger.i('再生が停止されました');
      } catch (e) {
        widget.logger.e('再生の停止に失敗しました: $e');
      }
    }
  }

  /// 録音の一時停止
  Future<void> _pauseRecording() async {
    if (_recordState == RecordState.record) {
      try {
        widget.logger.i('録音を一時停止します');
        await _audioService.pauseRecording();
        setState(() {
          _recordState = RecordState.pause;
        });
        widget.logger.i('録音が一時停止されました');
      } catch (e) {
        widget.logger.e('録音の一時停止に失敗しました: $e');
        rethrow;
      }
    }
  }

  /// 録音の再開
  Future<void> _resumeRecording() async {
    if (_recordState == RecordState.pause) {
      try {
        widget.logger.i('録音を再開します');
        await _audioService.resumeRecording();
        setState(() {
          _recordState = RecordState.record;
        });
        widget.logger.i('録音が再開されました');
      } catch (e) {
        widget.logger.e('録音の再開に失敗しました: $e');
        rethrow;
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
    widget.logger.i('RecorderとPlayerが破棄されました');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(widget.recordingStateNotifier);
    final isRecording = recordingState != RecordingState.stopped;
    final isPaused = recordingState == RecordingState.paused;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appTitle),
        actions: [
          if (_isInitialized && !isRecording)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: Strings.shareButtonTooltip,
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
                  onPauseRecording: _pauseRecording,
                  onResumeRecording: _resumeRecording,
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
      widget.logger.i('ファイル一覧の取得を開始します');
      final files = await _fileManagementService.getAudioFiles();
      widget.logger.i('${files.length}件のファイルを取得しました');

      for (final file in files) {
        widget.logger.i('- パス: ${file.path}');
        widget.logger.i('  ファイル名: ${file.name}');
        widget.logger.i('  作成日時: ${file.createdAt}');
        widget.logger.i('  共有: ${file.isShared}');
      }

      setState(() {
        _audioFiles = files;
      });
      widget.logger.i('ファイル一覧の更新が完了しました');
    } catch (e, stackTrace) {
      widget.logger.e('ファイル一覧の取得に失敗しました: $e\nスタックトレース: $stackTrace');
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
      widget.logger.e('再生の開始に失敗しました: $e');
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
