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
    _logger.i('録音状態が変更されました: ${recordState.name}');

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
            _logger.w('録音中断イベントを受信しました');
            await _handleRecordingInterrupted();
            return null;
          case 'RecordingResumed':
            _logger.i('録音再開イベントを受信しました');
            await _handleRecordingResumed();
            return null;
          case 'debugLog':
            _logger.d('Nativeデバッグログ: ${call.arguments}');
            return null;
          case 'GetRecordState':
            _logger.d('録音状態を取得します');
            return _audioServiceNotifier.recordState.name;
          default:
            _logger.e('未知のメソッド: ${call.method}');
            throw PlatformException(
              code: 'UNSUPPORTED_METHOD',
              message: 'Unknown method: ${call.method}',
            );
        }
      } catch (e) {
        _logger.e('メソッド呼び出しエラー: $e');
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
      _logger.i('録音を開始しました: $path');
    } catch (e) {
      _logger.e('録音の開始に失敗しました: $e');
      rethrow;
    }
  }

  /// 手動で録音を一時停止する
  Future<void> pauseRecording() async {
    try {
      _logger.i('録音を手動で一時停止します');
      if (_audioServiceNotifier.recordState == RecordState.record) {
        await _recorder.pause();
        _updateRecordState(RecordState.pause);
        _logger.i('録音が手動で一時停止されました');
      } else {
        _logger.w('録音を一時停止できません - 録音状態ではありません');
      }
    } catch (e) {
      _logger.e('録音の一時停止に失敗しました: $e');
      rethrow;
    }
  }

  /// 手動で録音を再開する
  Future<void> resumeRecording() async {
    try {
      _logger.i('録音を手動で再開します');
      if (_audioServiceNotifier.recordState == RecordState.pause) {
        await _recorder.resume();
        _updateRecordState(RecordState.record);
        _logger.i('録音が手動で再開されました');
      } else {
        _logger.w('録音を再開できません - 録音状態ではありません');
      }
    } catch (e) {
      _logger.e('録音の再開に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音を停止する
  Future<void> stopRecording() async {
    try {
      _logger.i('録音を停止します');
      if (await _recorder.isRecording() ||
          _audioServiceNotifier.recordState == RecordState.pause) {
        final path = await _recorder.stop();
        _updateRecordState(RecordState.stop);
        _logger.i('録音が停止されました: $path');
      } else {
        _logger.w('録音を停止できません - 録音状態ではありません');
      }
    } catch (e) {
      _logger.e('録音の停止に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音の一時停止（通話による中断）
  Future<void> _handleRecordingInterrupted() async {
    try {
      _logger.i('録音中断を処理します');
      _audioServiceNotifier.setHandlingInterruption(true);

      // 録音中の場合のみ処理を行う
      if (_audioServiceNotifier.recordState == RecordState.record) {
        // 電話に出た場合のみ一時停止する
        if (await _channel.invokeMethod<bool>('isPhoneCallActive') ?? false) {
          await _recorder.pause();
          _updateRecordState(RecordState.pause);
          _logger.i('通話による録音中断が発生しました');
        } else {
          _logger.i('通話が終了したため録音を継続します');
        }
      }
    } catch (e) {
      _logger.e('録音中断の処理に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音の再開（通話終了後）
  Future<void> _handleRecordingResumed() async {
    try {
      _logger.i('録音の再開を処理します');

      // 一時停止中の場合のみ再開する
      if (_audioServiceNotifier.recordState == RecordState.pause) {
        await _recorder.resume();
        _updateRecordState(RecordState.record);
        _logger.i('通話が終了したため録音を再開します');
      }

      _audioServiceNotifier.setHandlingInterruption(false);
    } catch (e) {
      _logger.e('録音の再開の処理に失敗しました: $e');
      rethrow;
    }
  }

  /// 再生を開始する
  ///
  /// [path] - 再生するファイルのパス
  Future<void> startPlaying(String path) async {
    try {
      _logger.i('再生を開始します');
      await _player.setVolume(1.0);
      await _player.setFilePath(path);
      await _player.play();
      _logger.i('再生が開始されました');
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
