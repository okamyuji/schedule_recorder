// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// Project imports:
import 'package:schedule_recorder/models/schedule_page/shared_audio_file.dart';

class MockSharedMediaFile extends Mock implements SharedMediaFile {}

void main() {
  group('SharedAudioFile Tests', () {
    late MockSharedMediaFile mockSharedMediaFile;

    setUp(() {
      mockSharedMediaFile = MockSharedMediaFile();
    });

    test('SharedAudioFile.fromSharedMediaFileが正しくインスタンスを作成する', () {
      // arrange
      final testPath = '/test/path/audio.m4a';
      final testMimeType = 'audio/mp4';

      when(() => mockSharedMediaFile.path).thenReturn(testPath);
      when(() => mockSharedMediaFile.mimeType).thenReturn(testMimeType);

      // act
      final sharedAudioFile =
          SharedAudioFile.fromSharedMediaFile(mockSharedMediaFile);

      // assert
      expect(sharedAudioFile.path, equals(testPath));
      expect(sharedAudioFile.mimeType, equals(testMimeType));
      expect(sharedAudioFile.timestamp, isA<DateTime>());
    });

    test('SharedAudioFile.fromSharedMediaFileがmimeTypeがnullの場合デフォルト値を設定する', () {
      // arrange
      final testPath = '/test/path/audio.m4a';

      when(() => mockSharedMediaFile.path).thenReturn(testPath);
      when(() => mockSharedMediaFile.mimeType).thenReturn(null);

      // act
      final sharedAudioFile =
          SharedAudioFile.fromSharedMediaFile(mockSharedMediaFile);

      // assert
      expect(sharedAudioFile.path, equals(testPath));
      expect(sharedAudioFile.mimeType, equals('audio/*'));
    });

    test('isAudioFileがmimeTypeに基づいて正しく判定する', () {
      // arrange
      const testCases = [
        {'mimeType': 'audio/mp4', 'path': 'test.m4a', 'expected': true},
        {'mimeType': 'audio/mpeg', 'path': 'test.mp3', 'expected': true},
        {'mimeType': 'video/mp4', 'path': 'test.mp4', 'expected': false},
        {'mimeType': 'application/pdf', 'path': 'test.pdf', 'expected': false},
      ];

      for (final testCase in testCases) {
        final sharedAudioFile = SharedAudioFile(
          path: testCase['path'] as String,
          mimeType: testCase['mimeType'] as String,
          timestamp: DateTime.now(),
        );

        // act & assert
        expect(
          sharedAudioFile.isAudioFile,
          equals(testCase['expected']),
          reason:
              'MimeType: ${testCase['mimeType']}, Path: ${testCase['path']}',
        );
      }
    });

    test('isAudioFileが拡張子に基づいて正しく判定する', () {
      // arrange
      const testCases = [
        {
          'mimeType': 'application/octet-stream',
          'path': 'test.mp3',
          'expected': true
        },
        {
          'mimeType': 'application/octet-stream',
          'path': 'test.m4a',
          'expected': true
        },
        {
          'mimeType': 'application/octet-stream',
          'path': 'test.wav',
          'expected': true
        },
        {
          'mimeType': 'application/octet-stream',
          'path': 'test.pdf',
          'expected': false
        },
      ];

      for (final testCase in testCases) {
        final sharedAudioFile = SharedAudioFile(
          path: testCase['path'] as String,
          mimeType: testCase['mimeType'] as String,
          timestamp: DateTime.now(),
        );

        // act & assert
        expect(
          sharedAudioFile.isAudioFile,
          equals(testCase['expected']),
          reason: 'Path: ${testCase['path']}',
        );
      }
    });
  });
}
