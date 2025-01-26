// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// Project imports:
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {
  final _stateController = StreamController<RecordState>.broadcast();

  @override
  Stream<RecordState> onStateChanged() => _stateController.stream;

  void emitState(RecordState state) {
    _stateController.add(state);
  }

  String get path => '/test/path';

  @override
  Future<void> dispose() async {
    await _stateController.close();
    return Future.value();
  }
}

class MockAudioPlayer extends Mock implements AudioPlayer {
  @override
  Future<void> dispose() async {}
}

class MockFileSharingService extends Mock implements FileSharingService {}

class MockFileManagementService extends Mock implements FileManagementService {}

class MockLogger extends Mock implements Logger {}

class MockRecordingStateNotifier extends Mock
    implements RecordingStateNotifier {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeRecordConfig extends Fake implements RecordConfig {}

class MockDirectory extends Mock implements Directory {
  @override
  String get path => '/test/path';
}

class MockAudioServiceNotifier extends AudioServiceNotifier {
  @override
  AudioServiceState build() {
    return const AudioServiceState(
      isHandlingInterruption: false,
      currentRecordingPath: null,
      recordState: RecordState.stop,
      lastInterruptionTime: null,
    );
  }

  @override
  void updateRecordState(RecordState recordState) {
    state = state.copyWith(recordState: recordState);
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  throw UnimplementedError();
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchedulePage Tests', () {
    late MockAudioRecorder mockRecorder;
    late MockAudioPlayer mockPlayer;
    late MockFileSharingService mockFileSharingService;
    late MockFileManagementService mockFileManagementService;
    late MockLogger mockLogger;
    late MockAudioServiceNotifier mockAudioServiceNotifier;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(FakeRecordConfig());
      registerFallbackValue(MockBuildContext());

      // モックの設定
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
          if (call.method == 'checkPermissionStatus') {
            return PermissionStatus.granted.index;
          }
          if (call.method == 'requestPermissions') {
            return {
              Permission.microphone.value: PermissionStatus.granted.index
            };
          }
          return null;
        },
      );

      // path_providerのモック
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return '/test/path';
          }
          return null;
        },
      );
    });

    setUp(() {
      mockRecorder = MockAudioRecorder();
      mockPlayer = MockAudioPlayer();
      mockFileSharingService = MockFileSharingService();
      mockFileManagementService = MockFileManagementService();
      mockLogger = MockLogger();
      mockAudioServiceNotifier = MockAudioServiceNotifier();
      final recordingStateNotifier = RecordingStateNotifier();

      container = ProviderContainer(
        overrides: [
          recordingStateNotifierProvider.overrideWith(
            () => recordingStateNotifier,
          ),
          audioServiceNotifierProvider.overrideWith(
            () => mockAudioServiceNotifier,
          ),
          audioServiceProvider.overrideWithValue(
            AudioService(
              recorder: mockRecorder,
              player: mockPlayer,
              logger: mockLogger,
              recordingStateNotifier: recordingStateNotifier,
              audioServiceNotifier: mockAudioServiceNotifier,
            ),
          ),
        ],
      );

      // Set up default mock behavior
      when(() => mockFileManagementService.getAudioFiles())
          .thenAnswer((_) async => []);
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);
      when(() => mockRecorder.isPaused()).thenAnswer((_) async => false);
      when(() => mockRecorder.start(
            any(),
            path: any(named: 'path'),
          )).thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => '');
      when(() => mockLogger.i(any())).thenAnswer((_) {});
      when(() => mockLogger.e(any())).thenAnswer((_) {});
      when(() => mockLogger.w(any())).thenAnswer((_) {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setFilePath(any())).thenAnswer((_) async => null);
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.stop()).thenAnswer((_) async {});
      when(() => mockPlayer.playerStateStream)
          .thenAnswer((_) => const Stream.empty());
      when(() =>
              mockFileSharingService.shareFiles(context: any(named: 'context')))
          .thenAnswer((_) async {});
    });

    Future<void> pumpSchedulePage(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(
              recorder: mockRecorder,
              player: mockPlayer,
              fileManagementService: mockFileManagementService,
              fileSharingService: mockFileSharingService,
              documentsPath: '/test/path',
              logger: mockLogger,
              recordingStateNotifier: recordingStateNotifierProvider,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('初期化時に正しく表示される', (WidgetTester tester) async {
      // arrange
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);
      when(() => mockRecorder.isPaused()).thenAnswer((_) async => false);
      when(() => mockFileManagementService.getAudioFiles())
          .thenAnswer((_) async => [
                AudioFile(
                  name: 'audio1.m4a',
                  path: '/test/path/audio1.m4a',
                  createdAt: DateTime.now(),
                  isShared: false,
                ),
              ]);

      // act
      await pumpSchedulePage(tester);

      // assert
      expect(find.byType(SchedulePage), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });
}
