import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class AudioService {
  static const MethodChannel _channel =
      MethodChannel('com.example.schedule_recorder/audio');

  /// ロガー
  static final Logger _logger = Logger();

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
          _logger.w('Received RecordingInterrupted event');
          onInterrupted();
          return;
        case 'RecordingResumed':
          _logger.i('Received RecordingResumed event');
          onResumed();
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
}
