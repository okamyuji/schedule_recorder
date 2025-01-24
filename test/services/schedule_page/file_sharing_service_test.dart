import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:schedule_recorder/services/schedule_page/file_sharing_service.dart';

import 'file_sharing_service_test.mocks.dart';

@GenerateMocks([Logger, BuildContext])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileSharingService service;
  late MockLogger mockLogger;
  late MockBuildContext mockContext;
  late Directory tempDir;

  setUp(() async {
    mockLogger = MockLogger();
    mockContext = MockBuildContext();
    service = FileSharingService(logger: mockLogger);

    // テスト用の一時ディレクトリを作成
    tempDir = await Directory.systemTemp.createTemp();

    // path_providerのモックを設定
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    // Share.shareXFilesのモックを設定
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  tearDown(() async {
    // テスト用の一時ディレクトリを削除
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }

    // モックをクリア
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'), null);
  });

  group('shareFiles', () {
    test('共有可能なファイルが存在しない場合、例外をスローする', () async {
      // 実行と検証
      await expectLater(
        () => service.shareFiles(
          context: mockContext,
          logPath: '${tempDir.path}/non_existent.log',
        ),
        throwsA(isA<ShareFilesException>()),
      );

      // ログの検証
      verify(mockLogger.w('ファイル共有を開始します')).called(1);
      verify(mockLogger.e(argThat(contains('共有可能なファイルが見つかりません')))).called(1);
    });

    test('録音ファイルとログファイルが存在する場合、両方のファイルが共有される', () async {
      // テストファイルを作成
      final recordingFile = File('${tempDir.path}/recording.m4a')..createSync();
      final logFile = File('${tempDir.path}/app.log')..createSync();

      // 実行
      await service.shareFiles(
        context: mockContext,
        logPath: logFile.path,
      );

      // ログの検証
      verifyInOrder([
        mockLogger.w('ファイル共有を開始します'),
        mockLogger.w(contains('録音ファイルを共有リストに追加')),
        mockLogger.w(contains('ログファイルを共有リストに追加')),
        mockLogger.w('ファイル共有が完了しました'),
      ]);

      // クリーンアップ
      recordingFile.deleteSync();
      logFile.deleteSync();
    });
  });
}
