import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

import 'main_test.mocks.dart';

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
  late MockAudioRecorder mockRecorder;
  late MockAudioPlayer mockPlayer;

  setUp(() {
    mockRecorder = MockAudioRecorder();
    mockPlayer = MockAudioPlayer();

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

    when(mockRecorder.start(
      RecordConfig(
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

  testWidgets('SchedulePageが正しく初期化される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ),
    );

    // 初期化中はCircularProgressIndicatorが表示される
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 非同期処理の完了を待つ
    await tester.pump(const Duration(milliseconds: 100));

    // 初期化が完了するとCircularProgressIndicatorが消える
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // RecordingButtonsが表示される
    expect(find.byType(RecordingButtons), findsOneWidget);

    // 初期状態では録音中/再生中のテキストが表示されない
    expect(find.text('録音中...'), findsNothing);
    expect(find.text('録音一時停止中...'), findsNothing);
    expect(find.text('再生中...'), findsNothing);
  });

  group('ScheduleRecorderApp', () {
    testWidgets('アプリが正しく初期化される', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        title: 'Schedule Recorder',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));

      // MaterialAppが存在することを確認
      expect(find.byType(MaterialApp), findsOneWidget);

      // アプリタイトルが正しいことを確認
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'Schedule Recorder');

      // テーマが正しく設定されていることを確認
      final ThemeData theme = app.theme!;
      final Color primaryColor = theme.colorScheme.primary;
      expect(primaryColor.b > primaryColor.r, isTrue);
      expect(primaryColor.b > primaryColor.g, isTrue);

      // SchedulePageが存在することを確認
      expect(find.byType(SchedulePage), findsOneWidget);

      // 初期化が完了するまで待つ
      await tester.pump(const Duration(milliseconds: 100));

      // RecordingButtonsが表示されることを確認
      expect(find.byType(RecordingButtons), findsOneWidget);
    });

    testWidgets('SchedulePageに正しい依存関係が注入される', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));

      // 初期化が完了するまで待つ
      await tester.pump(const Duration(milliseconds: 100));

      // SchedulePageが存在することを確認
      final schedulePage = find.byType(SchedulePage);
      expect(schedulePage, findsOneWidget);

      // 注入されたモックが正しいことを確認
      final SchedulePage page = tester.widget(schedulePage);
      expect(page.recorder, mockRecorder);
      expect(page.player, mockPlayer);
    });
  });
}
