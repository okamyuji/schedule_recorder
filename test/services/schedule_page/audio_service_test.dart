import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('com.example.schedule_recorder/audio');
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService', () {
    late List<String> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'setupNativeListeners calls onInterrupted when RecordingInterrupted is received',
        () async {
      // Arrange
      bool onInterruptedCalled = false;
      bool onResumedCalled = false;

      AudioService.setupNativeListeners(
        onInterrupted: () {
          onInterruptedCalled = true;
        },
        onResumed: () {
          onResumedCalled = true;
        },
      );

      // Act
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('RecordingInterrupted'),
        ),
        (ByteData? data) {},
      );

      // Assert
      expect(onInterruptedCalled, isTrue);
      expect(onResumedCalled, isFalse);
    });

    test(
        'setupNativeListeners calls onResumed when RecordingResumed is received',
        () async {
      // Arrange
      bool onInterruptedCalled = false;
      bool onResumedCalled = false;

      AudioService.setupNativeListeners(
        onInterrupted: () {
          onInterruptedCalled = true;
        },
        onResumed: () {
          onResumedCalled = true;
        },
      );

      // Act
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('RecordingResumed'),
        ),
        (ByteData? data) {},
      );

      // Assert
      expect(onInterruptedCalled, isFalse);
      expect(onResumedCalled, isTrue);
    });

    test('setupNativeListeners throws UnsupportedError for unknown method',
        () async {
      // Arrange
      AudioService.setupNativeListeners(
        onInterrupted: () {},
        onResumed: () {},
      );

      // Act & Assert
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'UnknownMethod') {
          throw PlatformException(
            code: 'UNSUPPORTED_METHOD',
            message: 'Unknown method: ${methodCall.method}',
          );
        }
        return null;
      });

      expect(
        () async {
          await channel.invokeMethod('UnknownMethod');
        },
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
