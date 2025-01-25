import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../providers/schedule_page/recording_state_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';

part 'audio_service.g.dart';

/// 録音サービスの状態
@immutable
class AudioServiceState {
  final bool isHandlingInterruption;
  final String? currentRecordingPath;
  final RecordState recordState;
  final DateTime? lastInterruptionTime;

  const AudioServiceState({
    this.isHandlingInterruption = false,
    this.currentRecordingPath,
    this.recordState = RecordState.stop,
    this.lastInterruptionTime,
  });

  AudioServiceState copyWith({
    bool? isHandlingInterruption,
    String? currentRecordingPath,
    RecordState? recordState,
    DateTime? lastInterruptionTime,
  }) {
    return AudioServiceState(
      isHandlingInterruption:
          isHandlingInterruption ?? this.isHandlingInterruption,
      currentRecordingPath: currentRecordingPath ?? this.currentRecordingPath,
      recordState: recordState ?? this.recordState,
      lastInterruptionTime: lastInterruptionTime ?? this.lastInterruptionTime,
    );
  }
}

/// オーディオサービスの状態を管理するプロバイダー
@riverpod
class AudioServiceNotifier extends _$AudioServiceNotifier {
  @override
  AudioServiceState build() => const AudioServiceState();

  RecordState get recordState => state.recordState;
  bool get isHandlingInterruption => state.isHandlingInterruption;
  String? get currentRecordingPath => state.currentRecordingPath;

  void updateRecordState(RecordState recordState) {
    state = AudioServiceState(
      isHandlingInterruption: state.isHandlingInterruption,
      currentRecordingPath: state.currentRecordingPath,
      recordState: recordState,
      lastInterruptionTime: state.lastInterruptionTime,
    );
  }

  void setHandlingInterruption(bool isHandling) {
    state = AudioServiceState(
      isHandlingInterruption: isHandling,
      currentRecordingPath: state.currentRecordingPath,
      recordState: state.recordState,
      lastInterruptionTime:
          isHandling ? DateTime.now() : state.lastInterruptionTime,
    );
  }

  void setCurrentRecordingPath(String? path) {
    state = AudioServiceState(
      isHandlingInterruption: state.isHandlingInterruption,
      currentRecordingPath: path,
      recordState: state.recordState,
      lastInterruptionTime: state.lastInterruptionTime,
    );
  }
}

/// オーディオサービス
class AudioService {
  static const MethodChannel _channel =
      MethodChannel('com.example.schedule_recorder/audio');

  final Logger _logger;
  final AudioPlayer _player;
  final RecordingStateNotifier _recordingStateNotifier;
  final AudioRecorder _recorder;
  final AudioServiceNotifier _audioServiceNotifier;
  StreamSubscription<RecordState>? _recordSub;

  AudioService({
    required AudioPlayer player,
    required Logger logger,
    required RecordingStateNotifier recordingStateNotifier,
    required AudioRecorder recorder,
    required AudioServiceNotifier audioServiceNotifier,
  })  : _player = player,
        _logger = logger,
        _recordingStateNotifier = recordingStateNotifier,
        _recorder = recorder,
        _audioServiceNotifier = audioServiceNotifier {
    _setupRecordStateListener();
  }

  void _setupRecordStateListener() {
    _recordSub = _recorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });
  }

  void _updateRecordState(RecordState recordState) {
    _audioServiceNotifier.updateRecordState(recordState);
    _logger
        .i(_formatLogMessage('Record state changed to: ${recordState.name}'));

    switch (recordState) {
      case RecordState.pause:
        _recordingStateNotifier.pauseRecording();
        break;
      case RecordState.record:
        _recordingStateNotifier.startRecording();
        break;
      case RecordState.stop:
        _recordingStateNotifier.stopRecording();
        break;
    }
  }

  /// ログメッセージに日時を追加する
  String _formatLogMessage(String message) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    return '[${formatter.format(now)}] $message';
  }

  /// ネイティブリスナーの設定
  ///
  /// [onInterrupted] - 録音中断時のコールバック
  /// [onResumed] - 録音再開時のコールバック
  void setupNativeListeners() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'RecordingInterrupted':
            _logger.w(_formatLogMessage('Received RecordingInterrupted event'));
            await _handleRecordingInterrupted();
            return null;
          case 'RecordingResumed':
            _logger.i(_formatLogMessage('Received RecordingResumed event'));
            await _handleRecordingResumed();
            return null;
          case 'debugLog':
            _logger.d(_formatLogMessage('Native debug log: ${call.arguments}'));
            return null;
          case 'GetRecordState':
            _logger.d(_formatLogMessage('Getting record state'));
            return _audioServiceNotifier.recordState.name;
          default:
            _logger.e(_formatLogMessage('Unknown method: ${call.method}'));
            throw PlatformException(
              code: 'UNSUPPORTED_METHOD',
              message: 'Unknown method: ${call.method}',
            );
        }
      } catch (e) {
        _logger.e(_formatLogMessage('Error handling method call: $e'));
        rethrow;
      }
    });
  }

  /// 録音を開始する
  Future<void> startRecording(String path) async {
    try {
      _audioServiceNotifier.setCurrentRecordingPath(path);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _updateRecordState(RecordState.record);
      _logger.i(_formatLogMessage('Recording started with path: $path'));
    } catch (e) {
      _logger.e(_formatLogMessage('Failed to start recording: $e'));
      rethrow;
    }
  }

  /// 手動で録音を一時停止する
  Future<void> pauseRecording() async {
    try {
      _logger.i(_formatLogMessage('Manually pausing recording...'));
      if (_audioServiceNotifier.recordState == RecordState.record) {
        await _recorder.pause();
        _updateRecordState(RecordState.pause);
        _logger.i(_formatLogMessage('Recording manually paused'));
      } else {
        _logger.w(_formatLogMessage(
            'Cannot pause - recorder is not in recording state'));
      }
    } catch (e) {
      _logger.e(_formatLogMessage('録音の一時停止に失敗しました: $e'));
      rethrow;
    }
  }

  /// 手動で録音を再開する
  Future<void> resumeRecording() async {
    try {
      _logger.i(_formatLogMessage('Manually resuming recording...'));
      if (_audioServiceNotifier.recordState == RecordState.pause) {
        await _recorder.resume();
        _updateRecordState(RecordState.record);
        _logger.i(_formatLogMessage('Recording manually resumed'));
      } else {
        _logger.w(_formatLogMessage(
            'Cannot resume - recorder is not in paused state'));
      }
    } catch (e) {
      _logger.e(_formatLogMessage('録音の再開に失敗しました: $e'));
      rethrow;
    }
  }

  /// 録音を停止する
  Future<void> stopRecording() async {
    try {
      _logger.i(_formatLogMessage('Stopping recording...'));
      if (await _recorder.isRecording() ||
          _audioServiceNotifier.recordState == RecordState.pause) {
        final path = await _recorder.stop();
        _updateRecordState(RecordState.stop);
        _logger.i(_formatLogMessage('Recording saved to: $path'));
        _logger.i(_formatLogMessage('Recording stopped successfully'));
      } else {
        _logger.w(_formatLogMessage(
            'Cannot stop - recorder is not recording or paused'));
      }
    } catch (e) {
      _logger.e(_formatLogMessage('Failed to stop recording: $e'));
      rethrow;
    }
  }

  /// 録音の一時停止（通話による中断）
  Future<void> _handleRecordingInterrupted() async {
    try {
      _logger.i(_formatLogMessage('Handling recording interruption...'));
      _audioServiceNotifier.setHandlingInterruption(true);

      // 録音中の場合のみ処理を行う
      if (_audioServiceNotifier.recordState == RecordState.record) {
        // 電話に出た場合のみ一時停止する
        if (await _channel.invokeMethod<bool>('isPhoneCallActive') ?? false) {
          await _recorder.pause();
          _updateRecordState(RecordState.pause);
          _logger.i(_formatLogMessage('Recording paused due to phone call'));
        } else {
          _logger.i(_formatLogMessage(
              'Continuing recording - phone call not answered'));
        }
      }
    } catch (e) {
      _logger
          .e(_formatLogMessage('Failed to handle recording interruption: $e'));
      rethrow;
    }
  }

  /// 録音の再開（通話終了後）
  Future<void> _handleRecordingResumed() async {
    try {
      _logger.i(_formatLogMessage('Handling recording resumption...'));

      // 一時停止中の場合のみ再開する
      if (_audioServiceNotifier.recordState == RecordState.pause) {
        await _recorder.resume();
        _updateRecordState(RecordState.record);
        _logger.i(_formatLogMessage('Recording resumed after phone call'));
      }

      _audioServiceNotifier.setHandlingInterruption(false);
    } catch (e) {
      _logger.e(_formatLogMessage('Failed to handle recording resumption: $e'));
      rethrow;
    }
  }

  /// 再生を開始する
  ///
  /// [path] - 再生するファイルのパス
  Future<void> startPlaying(String path) async {
    try {
      _logger.i(_formatLogMessage('Starting playback...'));
      await _player.setVolume(1.0);
      await _player.setFilePath(path);
      await _player.play();
      _logger.i(_formatLogMessage('Playback started'));
    } catch (e) {
      _logger.e(_formatLogMessage('再生開始エラー: $e'));
      rethrow;
    }
  }

  /// リソースの解放
  void dispose() {
    _recordSub?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}

/// オーディオサービスのプロバイダー
@Riverpod(keepAlive: true)
AudioService audioService(Ref ref) {
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: false,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.dateAndTime,
      noBoxingByDefault: true,
    ),
  );

  final player = AudioPlayer();
  final recorder = AudioRecorder();
  final recordingStateNotifier =
      ref.watch(recordingStateNotifierProvider.notifier);
  final audioServiceNotifier = ref.watch(audioServiceNotifierProvider.notifier);

  return AudioService(
    player: player,
    logger: logger,
    recordingStateNotifier: recordingStateNotifier,
    recorder: recorder,
    audioServiceNotifier: audioServiceNotifier,
  );
}
