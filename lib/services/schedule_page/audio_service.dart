import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../providers/recording_state_provider.dart';

part 'audio_service.g.dart';

/// オーディオサービス
@riverpod
AudioService audioService(Ref ref) {
  return AudioService(
    player: AudioPlayer(),
    logger: Logger(),
    recordingStateNotifier: ref.watch(recordingStateNotifierProvider.notifier),
  );
}

/// オーディオサービス
class AudioService {
  static const MethodChannel _channel =
      MethodChannel('com.example.schedule_recorder/audio');

  final Logger _logger;
  final AudioPlayer _player;
  final RecordingStateNotifier _recordingStateNotifier;

  /// オーディオサービスのコンストラクタ
  AudioService({
    required AudioPlayer player,
    required Logger logger,
    required RecordingStateNotifier recordingStateNotifier,
  })  : _player = player,
        _logger = logger,
        _recordingStateNotifier = recordingStateNotifier;

  /// ネイティブリスナーの設定
  ///
  /// [onInterrupted] - 録音中断時のコールバック
  /// [onResumed] - 録音再開時のコールバック
  void setupNativeListeners() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'RecordingInterrupted':
          _logger.w('Received RecordingInterrupted event');
          _recordingStateNotifier.pauseRecording();
          return;
        case 'RecordingResumed':
          _logger.i('Received RecordingResumed event');
          _recordingStateNotifier.resumeRecording();
          return;
        default:
          _logger.e('Unknown method: ${call.method}');
          throw PlatformException(
            code: 'UNSUPPORTED_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    });
  }

  /// 再生を開始する
  ///
  /// [path] - 再生するファイルのパス
  Future<void> startPlaying(String path) async {
    try {
      _logger.i('Starting playback...');
      await _player.setVolume(1.0);
      await _player.setFilePath(path);
      await _player.play();
      _logger.i('Playback started');
    } catch (e) {
      _logger.e('再生開始エラー: $e');
      rethrow;
    }
  }
}
