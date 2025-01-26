// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

// Project imports:
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';
import 'package:schedule_recorder/services/schedule_page/file_system.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class MockSharePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SharePlatform {}

class MockLogger extends Mock implements Logger {}

class MockFile extends Mock implements File {}

class MockBuildContext extends Mock implements BuildContext {}

class MockDirectory extends Mock implements Directory {}

class FakeXFile extends Fake implements XFile {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileSharingService Tests', () {
    late FileSharingService service;
    late MockLogger mockLogger;
    late MockFile mockFile;
    late MockBuildContext mockContext;
    late MockPathProviderPlatform mockPathProvider;
    late MockSharePlatform mockSharePlatform;
    const testDocPath = '/test/documents';
    const testFilePath = '/test/documents/recording.m4a';

    setUpAll(() {
      registerFallbackValue(FakeXFile());
      registerFallbackValue(<XFile>[]);
    });

    setUp(() {
      mockLogger = MockLogger();
      mockFile = MockFile();
      mockContext = MockBuildContext();
      mockPathProvider = MockPathProviderPlatform();
      mockSharePlatform = MockSharePlatform();

      // Set up path provider
      PathProviderPlatform.instance = mockPathProvider;
      when(() => mockPathProvider.getApplicationDocumentsPath())
          .thenAnswer((_) async => testDocPath);

      // Set up share platform
      SharePlatform.instance = mockSharePlatform;
      when(() => mockSharePlatform.shareXFiles(
                any(),
                subject: any(named: 'subject'),
              ))
          .thenAnswer(
              (_) async => const ShareResult('', ShareResultStatus.success));

      service = FileSharingService(logger: mockLogger);

      // Set up file mock
      when(() => mockFile.existsSync()).thenReturn(true);
      when(() => mockFile.path).thenReturn(testFilePath);

      // Logger mock setup
      when(() => mockLogger.w(any())).thenReturn(null);
      when(() => mockLogger.e(any())).thenReturn(null);

      // Reset and set up FileSystem
      FileSystem.reset();
      FileSystem.setFileFactory((_) => mockFile);
    });

    test('shareFilesが正常に動作する', () async {
      // arrange
      when(() => mockFile.existsSync()).thenReturn(true);

      // act
      await service.shareFiles(context: mockContext);

      // assert
      verify(() => mockLogger.w('ファイル共有を開始します')).called(1);
      verify(() => mockLogger.w('録音ファイルを共有リストに追加: $testFilePath')).called(1);
      verify(() => mockLogger.w('ファイル共有が完了しました')).called(1);
      verify(() => mockSharePlatform.shareXFiles(
            any(),
            subject: '録音データ',
          )).called(1);
    });

    test('shareFilesがファイルが存在しない場合例外を返す', () async {
      // arrange
      when(() => mockFile.existsSync()).thenReturn(false);

      // act & assert
      await expectLater(
        () => service.shareFiles(context: mockContext),
        throwsA(isA<ShareFilesException>()),
      );
      verify(() => mockLogger.e('共有可能なファイルが見つかりません')).called(1);
    });

    test('ShareFilesException.toStringがメッセージを返す', () {
      // arrange
      const message = 'Test error message';
      final exception = ShareFilesException(message);

      // act & assert
      expect(exception.toString(), equals(message));
    });
  });
}
