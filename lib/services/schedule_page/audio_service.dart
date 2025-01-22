import 'package:flutter/services.dart';

class AudioService {
  static const MethodChannel _channel =
      MethodChannel('com.example.schedule_recorder/audio');

  static void setupNativeListeners({
    required Function onInterrupted,
    required Function onResumed,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'RecordingInterrupted':
          onInterrupted();
          return;
        case 'RecordingResumed':
          onResumed();
          return;
        default:
          throw PlatformException(
            code: 'UNSUPPORTED_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    });
  }
}
