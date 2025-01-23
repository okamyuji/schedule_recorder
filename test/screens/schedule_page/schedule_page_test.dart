import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';

import 'schedule_page_test.mocks.dart';

// Mockクラスを生成するアノテーション
@GenerateMocks([FlutterSoundRecorder, FlutterSoundPlayer])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSoundRecorder mockRecorder;
  late MockFlutterSoundPlayer mockPlayer;

  // permission_handler関連のMethodChannel
  const MethodChannel permissionChannel =
      MethodChannel('com.example.schedule_recorder/audio');

  // path_provider関連のMethodChannel
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    // モックの初期化
    mockRecorder = MockFlutterSoundRecorder();
    mockPlayer = MockFlutterSoundPlayer();

    // Permission Handlerのモック設定（デフォルトは許可）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions') {
        final args = methodCall.arguments;
        if (args is List) {
          // 例: ['microphone']
          final result = <dynamic, dynamic>{};
          for (final item in args) {
            // デフォルトは許可
            result[item] = 2; // 2 = granted
          }
          return result;
        }
        if (args is Map) {
          // 例: {'microphone': true}
          final result = <dynamic, dynamic>{};
          args.forEach((key, value) {
            result[key] = 2; // 2 = granted
          });
          return result;
        }
        return <dynamic, dynamic>{'microphone': 2}; // fallback
      }
      return null;
    });

    // path_providerのモック設定
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel,
            (MethodCall methodCall) async {
      // テスト用のパスを返す
      return '/test/path';
    });

    // FlutterSoundRecorderの標準動作
    when(mockRecorder.openRecorder()).thenAnswer((_) async => null);
    when(mockRecorder.startRecorder(
      toFile: anyNamed('toFile'),
      codec: anyNamed('codec'),
    )).thenAnswer((_) async => '');
    when(mockRecorder.stopRecorder()).thenAnswer((_) async => '');
    when(mockRecorder.closeRecorder()).thenAnswer((_) async => {});

    // FlutterSoundPlayerの標準動作
    when(mockPlayer.openPlayer()).thenAnswer((_) async => null);
    when(mockPlayer.startPlayer(
      fromURI: anyNamed('fromURI'),
      codec: anyNamed('codec'),
      whenFinished: anyNamed('whenFinished'),
    )).thenAnswer((_) async => const Duration(seconds: 0));
    when(mockPlayer.stopPlayer()).thenAnswer((_) async => {});
    when(mockPlayer.closePlayer()).thenAnswer((_) async => {});
  });

  tearDown(() {
    // モックの解除
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  group('SchedulePage UI and Logic Tests', () {
    testWidgets('Displays initial UI correctly (not recording, not playing)',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));
      await tester.pumpAndSettle();

      // 初期表示: Start Recording / Play Recording
      expect(find.text('録音中...'), findsNothing);
      expect(find.text('再生中...'), findsNothing);
      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.text('Play Recording'), findsOneWidget);
    });

    testWidgets('dispose closes recorder/player', (WidgetTester tester) async {
      // create -> dispose
      await tester.pumpWidget(MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));

      // ウィジェットツリーから取り除く
      await tester.pumpWidget(Container());

      // closeRecorder, closePlayer が呼ばれていることを確認
      verify(mockRecorder.closeRecorder()).called(1);
      verify(mockPlayer.closePlayer()).called(1);
    });

    testWidgets('Exception handling in _startRecording logs error',
        (WidgetTester tester) async {
      // startRecorderが失敗するケース
      when(mockRecorder.startRecorder(
        toFile: anyNamed('toFile'),
        codec: anyNamed('codec'),
      )).thenThrow('Test Recorder Error');

      await tester.pumpWidget(MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));
      await tester.pumpAndSettle();

      // Start Recording
      await tester.tap(find.text('Start Recording'));
      await tester.pumpAndSettle();

      // 例外発生したがキャッチしてlogger.eを呼んでいる想定
      // UIは録音中にならない
      expect(find.text('Stop Recording'), findsNothing);
      expect(find.text('Start Recording'), findsOneWidget);
    });
    testWidgets('Exception handling in _startPlaying logs error',
        (WidgetTester tester) async {
      // startPlayerが失敗するケース
      when(mockPlayer.startPlayer(
        fromURI: anyNamed('fromURI'),
        codec: anyNamed('codec'),
        whenFinished: anyNamed('whenFinished'),
      )).thenThrow('Test start player error');

      await tester.pumpWidget(MaterialApp(
        home: SchedulePage(
          recorder: mockRecorder,
          player: mockPlayer,
        ),
      ));
      await tester.pumpAndSettle();

      // Play
      await tester.tap(find.text('Play Recording'));
      await tester.pumpAndSettle();

      // 失敗したのでStop Playingにはならない
      expect(find.text('Play Recording'), findsOneWidget);
      expect(find.text('Stop Playing'), findsNothing);
    });
  });
}
