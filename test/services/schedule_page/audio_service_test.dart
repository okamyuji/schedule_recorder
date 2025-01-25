import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import '../../mocks/recording_state_notifier_mock.dart';
import '../../mocks/audio_player_mock.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('com.example.schedule_recorder/audio');
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRecordingStateNotifier mockRecordingStateNotifier;

  setUp(() {
    mockRecordingStateNotifier = MockRecordingStateNotifier();
  });

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

    test('setupNativeListenersでRecordingInterruptedが受信されたらpauseRecordingが呼ばれる',
        () async {
      final audioService = AudioService(
        player: MockAudioPlayer(),
        logger: Logger(),
        recordingStateNotifier: mockRecordingStateNotifier,
      );

      audioService.setupNativeListeners();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('RecordingInterrupted'),
        ),
        (ByteData? data) {},
      );

      verify(mockRecordingStateNotifier.pauseRecording()).called(1);
    });

    test('setupNativeListenersでRecordingResumedが受信されたらresumeRecordingが呼ばれる',
        () async {
      final audioService = AudioService(
        player: MockAudioPlayer(),
        logger: Logger(),
        recordingStateNotifier: mockRecordingStateNotifier,
      );

      audioService.setupNativeListeners();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('RecordingResumed'),
        ),
        (ByteData? data) {},
      );

      verify(mockRecordingStateNotifier.resumeRecording()).called(1);
    });

    test('setupNativeListenersでUnknownMethodが受信されたらUnsupportedErrorがスローされる',
        () async {
      final audioService = AudioService(
        player: MockAudioPlayer(),
        logger: Logger(),
        recordingStateNotifier: mockRecordingStateNotifier,
      );

      audioService.setupNativeListeners();

      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('UnknownMethod'),
          ),
          (ByteData? data) {
            final exception = const StandardMethodCodec().decodeEnvelope(data!)
                as PlatformException;
            expect(exception.code, 'UNSUPPORTED_METHOD');
            expect(exception.message, 'Unknown method: UnknownMethod');
          },
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
