// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_system.dart';

class MockLogger extends Mock implements Logger {}

class MockDirectory extends Mock implements Directory {}

class MockFile extends Mock implements File {}

class MockFileStat extends Mock implements FileStat {}

class _FakeDirectory extends Fake implements Directory {}

class _FakeFile extends Fake implements File {}

void main() {
  group('FileManagementService Tests', () {
    late FileManagementService service;
    late MockLogger mockLogger;
    late MockDirectory mockDirectory;
    late MockFile mockFile;
    late MockFileStat mockFileStat;
    const testDocumentsPath = '/test/documents';
    const testFilePath = '/test/documents/test.m4a';

    setUpAll(() {
      registerFallbackValue(_FakeDirectory());
      registerFallbackValue(_FakeFile());
    });

    setUp(() {
      mockLogger = MockLogger();
      mockDirectory = MockDirectory();
      mockFile = MockFile();
      mockFileStat = MockFileStat();

      service = FileManagementService(
        logger: mockLogger,
        documentsPath: testDocumentsPath,
      );

      // Set up default mock behavior
      when(() => mockFile.path).thenReturn(testFilePath);
      when(() => mockFile.statSync()).thenReturn(mockFileStat);
      when(() => mockFileStat.changed).thenReturn(DateTime(2024, 1, 1));

      // Logger mock setup
      when(() => mockLogger.i(any())).thenReturn(null);
      when(() => mockLogger.e(any())).thenReturn(null);

      // Reset FileSystem
      FileSystem.reset();
    });

    group('getAudioFiles', () {
      test('AudioFileのリストを返す', () async {
        // arrange
        final mockStream = Stream.fromIterable([mockFile]);
        when(() => mockDirectory.list()).thenAnswer((_) => mockStream);
        when(() => mockFile.path).thenReturn(testFilePath);

        // Override FileSystem factories
        FileSystem.setDirectoryFactory((_) => mockDirectory);

        // act
        final result = await service.getAudioFiles();

        // assert
        expect(result, isA<List<AudioFile>>());
        expect(result.length, equals(1));
        expect(result.first.path, equals(testFilePath));
        verify(() => mockLogger.i(any())).called(1);
      });

      test('ディレクトリのリスト取得に失敗した場合例外を返す', () async {
        // arrange
        when(() => mockDirectory.list())
            .thenThrow(Exception('Failed to list directory'));

        // Override FileSystem factories
        FileSystem.setDirectoryFactory((_) => mockDirectory);

        // act & assert
        await expectLater(
          () => service.getAudioFiles(),
          throwsException,
        );
        verify(() => mockLogger.e(any())).called(1);
      });
    });

    group('deleteFile', () {
      test('ファイルを正常に削除する', () async {
        // arrange
        when(() => mockFile.delete()).thenAnswer((_) => Future.value(mockFile));

        // Override FileSystem factories
        FileSystem.setFileFactory((_) => mockFile);

        // act
        await service.deleteFile(testFilePath);

        // assert
        verify(() => mockFile.delete()).called(1);
        verify(() => mockLogger.i(any())).called(1);
      });

      test('ファイル削除に失敗した場合例外を返す', () async {
        // arrange
        when(() => mockFile.delete())
            .thenThrow(Exception('Failed to delete file'));

        // Override FileSystem factories
        FileSystem.setFileFactory((_) => mockFile);

        // act & assert
        await expectLater(
          () => service.deleteFile(testFilePath),
          throwsException,
        );
        verify(() => mockLogger.e(any())).called(1);
      });
    });
  });
}
