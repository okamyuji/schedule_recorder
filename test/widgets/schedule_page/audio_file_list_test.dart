import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';
import 'package:schedule_recorder/widgets/schedule_page/audio_file_list.dart';

void main() {
  group('AudioFileList', () {
    late List<AudioFile> testFiles;
    late Function(AudioFile) onPlayTap;
    late Function(AudioFile) onDeleteTap;

    setUp(() {
      testFiles = [
        AudioFile(
          path: '/test/path/recording.m4a',
          name: 'recording.m4a',
          createdAt: DateTime(2024, 1, 1),
          isShared: false,
        ),
        AudioFile(
          path: '/test/path/shared.mp3',
          name: 'shared.mp3',
          createdAt: DateTime(2024, 1, 2),
          isShared: true,
        ),
      ];

      onPlayTap = (_) {};
      onDeleteTap = (_) {};
    });

    testWidgets('ファイル一覧が正しく表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioFileList(
              files: testFiles,
              onPlayTap: onPlayTap,
              onDeleteTap: onDeleteTap,
            ),
          ),
        ),
      );

      // ファイル名が表示されていることを確認
      expect(find.text('recording.m4a'), findsOneWidget);
      expect(find.text('shared.mp3'), findsOneWidget);

      // 日付が表示されていることを確認
      expect(find.text('2024/01/01 00:00'), findsOneWidget);
      expect(find.text('2024/01/02 00:00'), findsOneWidget);

      // アイコンが表示されていることを確認
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
      expect(find.byIcon(Icons.delete), findsNWidgets(2));
    });

    testWidgets('再生ボタンをタップすると onPlayTap が呼ばれる', (WidgetTester tester) async {
      AudioFile? tappedFile;
      onPlayTap = (file) => tappedFile = file;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioFileList(
              files: testFiles,
              onPlayTap: onPlayTap,
              onDeleteTap: onDeleteTap,
            ),
          ),
        ),
      );

      // 最初のファイルの再生ボタンをタップ
      await tester.tap(find.byIcon(Icons.play_arrow).first);
      expect(tappedFile, equals(testFiles[0]));

      // 2番目のファイルの再生ボタンをタップ
      await tester.tap(find.byIcon(Icons.play_arrow).last);
      expect(tappedFile, equals(testFiles[1]));
    });

    testWidgets('削除ボタンをタップすると onDeleteTap が呼ばれる', (WidgetTester tester) async {
      AudioFile? tappedFile;
      onDeleteTap = (file) => tappedFile = file;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioFileList(
              files: testFiles,
              onPlayTap: onPlayTap,
              onDeleteTap: onDeleteTap,
            ),
          ),
        ),
      );

      // 最初のファイルの削除ボタンをタップ
      await tester.tap(find.byIcon(Icons.delete).first);
      expect(tappedFile, equals(testFiles[0]));

      // 2番目のファイルの削除ボタンをタップ
      await tester.tap(find.byIcon(Icons.delete).last);
      expect(tappedFile, equals(testFiles[1]));
    });
  });
}
