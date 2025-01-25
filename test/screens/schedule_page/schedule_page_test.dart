import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_recorder/providers/recording_state_provider.dart';
import '../../mocks/recording_state_notifier_mock.dart';

import 'schedule_page_test.mocks.dart';

class MockPermissionHandlerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return PermissionStatus.granted;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
      List<Permission> permissions) async {
    return {
      for (var permission in permissions) permission: PermissionStatus.granted,
    };
  }
}

@GenerateMocks([AudioRecorder, AudioPlayer])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioRecorder mockRecorder;
  late MockAudioPlayer mockPlayer;
  late MockRecordingStateNotifier mockRecordingStateNotifier;

  setUp(() {
    mockRecorder = MockAudioRecorder();
    mockPlayer = MockAudioPlayer();
    mockRecordingStateNotifier = MockRecordingStateNotifier();

    // パーミッションのモックを設定
    final mockPermissionHandler = MockPermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = mockPermissionHandler;

    // path_providerのモック設定
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      return '/test/path';
    });

    // 基本的なモックの設定
    when(mockRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: anyNamed('path'),
    )).thenAnswer((_) async {});

    when(mockRecorder.stop()).thenAnswer((_) async => 'test_path');
    when(mockRecorder.pause()).thenAnswer((_) async {});
    when(mockRecorder.resume()).thenAnswer((_) async {});

    when(mockPlayer.setVolume(any)).thenAnswer((_) async {});
    when(mockPlayer.setFilePath(any)).thenAnswer((_) async => Duration.zero);
    when(mockPlayer.play()).thenAnswer((_) async {});
    when(mockPlayer.stop()).thenAnswer((_) async {});
    when(mockPlayer.playerStateStream).thenAnswer(
        (_) => Stream.value(PlayerState(false, ProcessingState.idle)));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  Future<void> pumpSchedulePage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingStateNotifierProvider.overrideWith(
            () => mockRecordingStateNotifier,
          ),
        ],
        child: MaterialApp(
          home: SchedulePage(
            recorder: mockRecorder,
            player: mockPlayer,
            fileManagementService: FileManagementService(
              logger: Logger(),
              documentsPath: '/test/path',
            ),
            documentsPath: '/test/path',
            logger: Logger(),
            recordingStateNotifier: mockRecordingStateNotifier,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  testWidgets('再生の開始と停止が正しく動作する', (tester) async {
    await pumpSchedulePage(tester);

    // 再生開始
    await tester.tap(find.byKey(const Key('play_button')));
    await tester.pump();

    expect(find.text('再生中...'), findsOneWidget);

    // 再生停止
    await tester.tap(find.byKey(const Key('stop_button')));
    await tester.pump();

    expect(find.text('再生中...'), findsNothing);
  });

  testWidgets('録音の中断と再開のテスト', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
          fileManagementService: FileManagementService(
            logger: Logger(),
            documentsPath: '/test/path',
          ),
          documentsPath: '/test/path',
          logger: Logger(),
          recordingStateNotifier: mockRecordingStateNotifier,
        ),
      ),
    );

    // 初期化待ち
    await tester.pump(const Duration(milliseconds: 100));

    // 録音開始
    await tester.tap(find.byKey(const Key('record_button')));
    await tester.pump();

    // 録音開始時の状態を確認
    expect(find.text('録音中...'), findsOneWidget);
    expect(find.text('録音一時停止中...'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsOneWidget);
    expect(find.byKey(const Key('resume_button')), findsNothing);

    // 電話着信（録音は継続）
    // この時点では録音は継続されるため、状態は変化しない
    expect(find.text('録音中...'), findsOneWidget);
    expect(find.text('録音一時停止中...'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsOneWidget);
    expect(find.byKey(const Key('resume_button')), findsNothing);

    // 電話に出た場合（録音は一時停止）
    await tester.tap(find.byKey(const Key('pause_button')));
    await tester.pump();

    // 一時停止時の状態を確認
    expect(find.text('録音一時停止中...'), findsOneWidget);
    expect(find.text('録音中...'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsNothing);
    expect(find.byKey(const Key('resume_button')), findsOneWidget);
    verify(mockRecorder.pause()).called(1);

    // 電話を切った場合（録音は再開）
    await tester.tap(find.byKey(const Key('resume_button')));
    await tester.pump();

    // 録音再開時の状態を確認
    expect(find.text('録音中...'), findsOneWidget);
    expect(find.text('録音一時停止中...'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsOneWidget);
    expect(find.byKey(const Key('resume_button')), findsNothing);
    verify(mockRecorder.resume()).called(1);

    // 録音停止
    await tester.tap(find.byKey(const Key('record_stop_button')));
    await tester.pump();

    // 録音停止時の状態を確認
    expect(find.text('録音中...'), findsNothing);
    expect(find.text('録音一時停止中...'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsNothing);
    expect(find.byKey(const Key('resume_button')), findsNothing);
    verify(mockRecorder.stop()).called(1);
  });

  testWidgets('SchedulePage should build without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingStateNotifierProvider.overrideWith(
            () => mockRecordingStateNotifier,
          ),
        ],
        child: MaterialApp(
          home: SchedulePage(
            recorder: mockRecorder,
            player: mockPlayer,
            fileManagementService: FileManagementService(
              logger: Logger(),
              documentsPath: '/test/path',
            ),
            documentsPath: '/test/path',
            logger: Logger(),
            recordingStateNotifier: mockRecordingStateNotifier,
          ),
        ),
      ),
    );
    expect(find.byType(SchedulePage), findsOneWidget);
  });
}
