import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

void main() {
  group('RecordingButtons', () {
    testWidgets('初期状態で正しく表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: false,
              isPlaying: false,
              isPaused: false,
              onStartRecording: null,
              onStopRecording: null,
              onStartPlaying: null,
              onStopPlaying: null,
              onPauseRecording: null,
              onResumeRecording: null,
            ),
          ),
        ),
      );

      // すべてのボタンが存在することを確認
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNWidgets(2)); // 録音停止と再生停止

      // 一時停止ボタンが表示されていないことを確認
      expect(find.byIcon(Icons.pause), findsNothing);

      // ツールチップが正しく設定されていることを確認
      expect(find.byTooltip('録音開始'), findsOneWidget);
      expect(find.byTooltip('録音停止'), findsOneWidget);
      expect(find.byTooltip('再生開始'), findsOneWidget);
      expect(find.byTooltip('再生停止'), findsOneWidget);

      // ボタンの色が黒であることを確認
      final recordButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.mic),
          matching: find.byType(IconButton),
        ),
      );
      expect(recordButton.color, Colors.black);

      final playButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(IconButton),
        ),
      );
      expect(playButton.color, Colors.black);
    });

    testWidgets('録音中は適切なボタンが有効/無効になる', (WidgetTester tester) async {
      bool recordingStopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: true,
              isPlaying: false,
              isPaused: false,
              onStartRecording: null,
              onStopRecording: () => recordingStopped = true,
              onStartPlaying: null,
              onStopPlaying: null,
              onPauseRecording: null,
              onResumeRecording: null,
            ),
          ),
        ),
      );

      // 録音ボタンが赤色になることを確認
      final recordButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.mic),
          matching: find.byType(IconButton),
        ),
      );
      expect(recordButton.color, Colors.red);

      // 一時停止ボタンが表示されることを確認
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 録音停止ボタンが有効で赤色になることを確認
      final stopRecordButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('録音停止'),
          matching: find.byType(IconButton),
        ),
      );
      expect(stopRecordButton.onPressed, isNotNull);
      expect(stopRecordButton.color, Colors.red);

      // 再生ボタンが無効になることを確認
      final playButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(IconButton),
        ),
      );
      expect(playButton.onPressed, isNull);

      // 録音停止ボタンをタップ
      await tester.tap(find.byTooltip('録音停止'));
      expect(recordingStopped, isTrue);
    });

    testWidgets('録音の一時停止と再開が正しく動作する', (WidgetTester tester) async {
      bool recordingPaused = false;
      bool recordingResumed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: true,
              isPlaying: false,
              isPaused: false,
              onStartRecording: null,
              onStopRecording: null,
              onStartPlaying: null,
              onStopPlaying: null,
              onPauseRecording: () => recordingPaused = true,
              onResumeRecording: () => recordingResumed = true,
            ),
          ),
        ),
      );

      // 一時停止ボタンが表示されることを確認
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byTooltip('録音一時停止'), findsOneWidget);

      // 一時停止ボタンをタップ
      await tester.tap(find.byTooltip('録音一時停止'));
      expect(recordingPaused, isTrue);

      // 一時停止状態でUIを更新
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: true,
              isPlaying: false,
              isPaused: true,
              onStartRecording: null,
              onStopRecording: null,
              onStartPlaying: null,
              onStopPlaying: null,
              onPauseRecording: () => recordingPaused = true,
              onResumeRecording: () => recordingResumed = true,
            ),
          ),
        ),
      );

      // 再開ボタンが表示されることを確認
      expect(find.byIcon(Icons.play_arrow), findsNWidgets(2)); // 再生ボタンと再開ボタン
      expect(find.byTooltip('録音再開'), findsOneWidget);

      // 再開ボタンをタップ
      await tester.tap(find.byTooltip('録音再開'));
      expect(recordingResumed, isTrue);
    });

    testWidgets('再生中は適切なボタンが有効/無効になる', (WidgetTester tester) async {
      bool playingStopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: false,
              isPlaying: true,
              isPaused: false,
              onStartRecording: null,
              onStopRecording: null,
              onStartPlaying: null,
              onStopPlaying: () => playingStopped = true,
              onPauseRecording: null,
              onResumeRecording: null,
            ),
          ),
        ),
      );

      // 再生ボタンが緑色になることを確認
      final playButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(IconButton),
        ),
      );
      expect(playButton.color, Colors.green);

      // 再生停止ボタンが有効で緑色になることを確認
      final stopPlayButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('再生停止'),
          matching: find.byType(IconButton),
        ),
      );
      expect(stopPlayButton.onPressed, isNotNull);
      expect(stopPlayButton.color, Colors.green);

      // 再生停止ボタンをタップ
      await tester.tap(find.byTooltip('再生停止'));
      expect(playingStopped, isTrue);
    });

    testWidgets('コールバックが正しく呼び出される', (WidgetTester tester) async {
      bool recordingStarted = false;
      bool playingStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: false,
              isPlaying: false,
              isPaused: false,
              onStartRecording: () => recordingStarted = true,
              onStopRecording: null,
              onStartPlaying: () => playingStarted = true,
              onStopPlaying: null,
              onPauseRecording: null,
              onResumeRecording: null,
            ),
          ),
        ),
      );

      // 録音開始ボタンをタップ
      await tester.tap(find.byTooltip('録音開始'));
      expect(recordingStarted, isTrue);

      // 再生開始ボタンをタップ
      await tester.tap(find.byTooltip('再生開始'));
      expect(playingStarted, isTrue);
    });

    testWidgets('録音中は再生ボタンが無効になる', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingButtons(
              isRecording: true,
              isPlaying: false,
              isPaused: false,
              onStartRecording: null,
              onStopRecording: null,
              onStartPlaying: null,
              onStopPlaying: null,
              onPauseRecording: null,
              onResumeRecording: null,
            ),
          ),
        ),
      );

      // 再生ボタンが無効になっていることを確認
      final playButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(IconButton),
        ),
      );
      expect(playButton.onPressed, isNull);
    });
  });
}
