import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';

@GenerateNiceMocks([
  MockSpec<Logger>(),
  MockSpec<File>(),
  MockSpec<Directory>(),
  MockSpec<FileStat>()
])
import 'file_management_service_test.mocks.dart';

void main() {
  late FileManagementService service;
  late MockLogger mockLogger;
  late MockDirectory mockDirectory;
  late String testPath;

  setUp(() {
    mockLogger = MockLogger();
    mockDirectory = MockDirectory();
    testPath = '/test/path';

    // DirectoryのインスタンスをモックするためのスタブをIOOverridesで設定
    IOOverrides.global = _TestIOOverrides(mockDirectory);

    service = FileManagementService(
      logger: mockLogger,
      documentsPath: testPath,
    );

    // Loggerのメソッドが呼ばれた時の動作を定義
    when(mockLogger.i(any)).thenReturn(null);
    when(mockLogger.e(any)).thenReturn(null);
  });

  tearDown(() {
    IOOverrides.global = null;
  });

  group('getAudioFiles', () {
    test('音声ファイルが正しく取得できる', () async {
      // テスト用のファイルを準備
      final mockFile1 = MockFile();
      final mockFile2 = MockFile();
      final mockStat1 = MockFileStat();
      final mockStat2 = MockFileStat();

      // ファイルのパスを設定
      when(mockFile1.path).thenReturn('/test/path/recording.m4a');
      when(mockFile2.path).thenReturn('/test/path/shared.mp3');

      // ファイルの状態を設定
      when(mockFile1.statSync()).thenReturn(mockStat1);
      when(mockFile2.statSync()).thenReturn(mockStat2);
      when(mockStat1.changed).thenReturn(DateTime(2024, 1, 1));
      when(mockStat2.changed).thenReturn(DateTime(2024, 1, 2));

      // ディレクトリの内容をモック
      when(mockDirectory.list()).thenAnswer((_) => Stream.fromIterable([
            mockFile1,
            mockFile2,
          ]));

      // サービスのメソッドを実行
      final files = await service.getAudioFiles();

      // 結果を検証
      expect(files.length, 2);
      expect(files[0].path, '/test/path/recording.m4a');
      expect(files[0].isShared, false);
      expect(files[1].path, '/test/path/shared.mp3');
      expect(files[1].isShared, true);

      // ログが出力されたことを確認
      verify(mockLogger.i('2 個の音声ファイルを検出しました')).called(1);
    });

    test('音声ファイルが存在しない場合は空のリストを返す', () async {
      // 空のディレクトリをモック
      when(mockDirectory.list()).thenAnswer((_) => Stream.fromIterable([]));

      // サービスのメソッドを実行
      final files = await service.getAudioFiles();

      // 結果を検証
      expect(files, isEmpty);

      // ログが出力されたことを確認
      verify(mockLogger.i('0 個の音声ファイルを検出しました')).called(1);
    });

    test('ディレクトリの読み取りに失敗した場合は例外をスロー', () async {
      // ディレクトリの読み取りが失敗するようにモック
      when(mockDirectory.list()).thenAnswer(
        (_) => Stream.fromFuture(
          Future.error(OSError('Directory not found', 2)),
        ),
      );

      // サービスのメソッドを実行し、例外が発生することを確認
      await expectLater(
        service.getAudioFiles(),
        throwsA(isA<OSError>()),
      );

      // エラーログが出力されたことを確認
      verify(mockLogger.e(argThat(contains('ファイル一覧の取得に失敗しました')))).called(1);
    });
  });

  group('deleteFile', () {
    test('ファイルが正しく削除される', () async {
      // テスト用のファイルを準備
      final mockFile = MockFile();
      final testFilePath = '/test/path/file.m4a';

      // ファイルの削除が成功するようにモック
      when(mockFile.delete()).thenAnswer((_) => Future.value(mockFile));

      // ファイルのインスタンスをモックするためのスタブをIOOverridesで設定
      IOOverrides.global = _TestIOOverrides(mockDirectory, mockFile);

      // サービスのメソッドを実行
      await service.deleteFile(testFilePath);

      // ログが出力されたことを確認
      verify(mockLogger.i('ファイルを削除しました: $testFilePath')).called(1);
    });

    test('ファイル削除に失敗した場合は例外をスロー', () async {
      // テスト用のファイルを準備
      final mockFile = MockFile();
      final testFilePath = '/test/path/file.m4a';
      final expectedError = Exception('削除エラー');

      // ファイルの削除が失敗するようにモック
      when(mockFile.delete()).thenThrow(expectedError);

      // ファイルのインスタンスをモックするためのスタブをIOOverridesで設定
      IOOverrides.global = _TestIOOverrides(mockDirectory, mockFile);

      // サービスのメソッドを実行し、例外が発生することを確認
      expect(() => service.deleteFile(testFilePath), throwsException);

      // エラーログが出力されたことを確認
      verify(mockLogger.e(argThat(contains('ファイル削除に失敗しました')))).called(1);
    });
  });
}

/// テスト用のIOOverrides
class _TestIOOverrides extends IOOverrides {
  final Directory _mockDirectory;
  final File? _mockFile;

  _TestIOOverrides(this._mockDirectory, [this._mockFile]);

  @override
  Directory createDirectory(String path) => _mockDirectory;

  @override
  File createFile(String path) => _mockFile ?? File(path);
}
