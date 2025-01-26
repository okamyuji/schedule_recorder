// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';

class MockFile extends Mock implements File {}

class MockFileStat extends Mock implements FileStat {}

void main() {
  group('AudioFile Tests', () {
    late MockFile mockFile;
    late MockFileStat mockFileStat;

    setUp(() {
      mockFile = MockFile();
      mockFileStat = MockFileStat();
      registerFallbackValue(DateTime(2024));
    });

    test('AudioFile.fromFileが正しくインスタンスを作成する', () {
      // arrange
      final testPath = '/test/path/audio.m4a';
      final testDateTime = DateTime(2024, 1, 1);

      when(() => mockFile.path).thenReturn(testPath);
      when(() => mockFile.statSync()).thenReturn(mockFileStat);
      when(() => mockFileStat.changed).thenReturn(testDateTime);

      // act
      final audioFile = AudioFile.fromFile(mockFile);

      // assert
      expect(audioFile.path, equals(testPath));
      expect(audioFile.name, equals('audio.m4a'));
      expect(audioFile.createdAt, equals(testDateTime));
      expect(audioFile.isShared, equals(!testPath.contains('recording')));
    });

    test('AudioFileコンストラクタが正しくインスタンスを作成する', () {
      // arrange
      final testPath = '/test/path/audio.m4a';
      final testName = 'audio.m4a';
      final testDateTime = DateTime(2024, 1, 1);
      final testIsShared = true;

      // act
      final audioFile = AudioFile(
        path: testPath,
        name: testName,
        createdAt: testDateTime,
        isShared: testIsShared,
      );

      // assert
      expect(audioFile.path, equals(testPath));
      expect(audioFile.name, equals(testName));
      expect(audioFile.createdAt, equals(testDateTime));
      expect(audioFile.isShared, equals(testIsShared));
    });
  });
}
