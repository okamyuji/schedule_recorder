import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

class AudioService {
  static const MethodChannel _channel =
      MethodChannel('com.example.schedule_recorder/audio');

  static final Logger _staticLogger = Logger();
  final Logger _logger;
  final AudioPlayer _player;

  AudioService({
    required AudioPlayer player,
    required Logger logger,
  })  : _player = player,
        _logger = logger;

  /// ネイティブリスナーの設定
  ///
  /// [onInterrupted] - 録音中断時のコールバック
  /// [onResumed] - 録音再開時のコールバック
  static void setupNativeListeners({
    required VoidCallback onInterrupted,
    required VoidCallback onResumed,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'RecordingInterrupted':
          _staticLogger.w('Received RecordingInterrupted event');
          onInterrupted();
          return;
        case 'RecordingResumed':
          _staticLogger.i('Received RecordingResumed event');
          onResumed();
          return;
        default:
          _staticLogger.e('Unknown method: ${call.method}');
          throw PlatformException(
            code: 'UNSUPPORTED_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    });
  }

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
