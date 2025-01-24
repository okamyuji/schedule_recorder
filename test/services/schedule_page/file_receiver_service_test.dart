import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:schedule_recorder/services/schedule_page/file_receiver_service.dart';

import 'file_receiver_service_test.mocks.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/test/path';
}

@GenerateNiceMocks([
  MockSpec<Logger>(),
  MockSpec<Directory>(),
  MockSpec<File>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileReceiverService service;
  late Logger mockLogger;
  late File mockFile;

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    mockLogger = MockLogger();
    mockFile = MockFile();
    service = FileReceiverService(logger: mockLogger);
  });

  group('FileReceiverService', () {
    test('音声ファイルを正しく処理できること', () async {
      final audioFile = SharedMediaFile(
        path: 'test.m4a',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );
      bool audioCallbackCalled = false;
      bool logCallbackCalled = false;

      await service.processSharedFiles(
        [audioFile],
        (_) => audioCallbackCalled = true,
        (_) => logCallbackCalled = true,
      );

      expect(audioCallbackCalled, true);
      expect(logCallbackCalled, false);
      verify(mockLogger.i('共有されたファイルの処理を開始: 1個のファイル')).called(1);
      verify(mockLogger.i('音声ファイルを受信: test.m4a')).called(1);
    });

    test('ログファイルを正しく処理できること', () async {
      final logFile = SharedMediaFile(
        path: 'test.log',
        type: SharedMediaType.text,
        thumbnail: null,
        duration: null,
      );
      bool audioCallbackCalled = false;
      bool logCallbackCalled = false;

      await service.processSharedFiles(
        [logFile],
        (_) => audioCallbackCalled = true,
        (_) => logCallbackCalled = true,
      );

      expect(audioCallbackCalled, false);
      expect(logCallbackCalled, true);
      verify(mockLogger.i('共有されたファイルの処理を開始: 1個のファイル')).called(1);
      verify(mockLogger.i('ログファイルを受信: test.log')).called(1);
    });

    test('未対応の拡張子のファイルを適切に処理できること', () async {
      final unknownFile = SharedMediaFile(
        path: 'test.xyz',
        type: SharedMediaType.image,
        thumbnail: null,
        duration: null,
      );
      bool audioCallbackCalled = false;
      bool logCallbackCalled = false;

      await service.processSharedFiles(
        [unknownFile],
        (_) => audioCallbackCalled = true,
        (_) => logCallbackCalled = true,
      );

      expect(audioCallbackCalled, false);
      expect(logCallbackCalled, false);
      verify(mockLogger.i('共有されたファイルの処理を開始: 1個のファイル')).called(1);
      verify(mockLogger.w('未対応のファイル形式: test.xyz')).called(1);
    });

    test('ファイルのコピーが成功すること', () async {
      when(mockFile.copy('/test/path/newfile.m4a'))
          .thenAnswer((_) => Future.value(mockFile));
      when(mockLogger.i(any)).thenReturn(null);

      final result = await service.copyFileToDocuments(mockFile, 'newfile.m4a');

      expect(result, '/test/path/newfile.m4a');
      verify(mockLogger.i('ファイルをコピーしました: /test/path/newfile.m4a')).called(1);
    });

    test('ファイルのコピーが失敗した場合、例外をスローすること', () async {
      final expectedError = Exception('コピーエラー');
      when(mockFile.copy('/test/path/newfile.m4a')).thenThrow(expectedError);
      when(mockLogger.e(any)).thenReturn(null);

      await expectLater(
        () => service.copyFileToDocuments(mockFile, 'newfile.m4a'),
        throwsA(expectedError),
      );

      verify(mockLogger.e('ファイルのコピーに失敗: $expectedError')).called(1);
    });
  });
}
