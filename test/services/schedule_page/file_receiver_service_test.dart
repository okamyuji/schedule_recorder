import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:schedule_recorder/services/schedule_page/file_receiver_service.dart';

import 'file_receiver_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Logger>(),
  MockSpec<Directory>(),
  MockSpec<File>(),
])
class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/test/path';
}

class MockFileFactory {
  static final Map<String, MockFile> _files = {};

  static MockFile getMockFile(String path) {
    return _files.putIfAbsent(path, () {
      final mockFile = MockFile();
      when(mockFile.path).thenReturn(path);
      when(mockFile.exists()).thenAnswer((_) => Future.value(true));
      when(mockFile.readAsBytes())
          .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));
      when(mockFile.writeAsBytes(any, flush: anyNamed('flush')))
          .thenAnswer((_) => Future.value(mockFile));
      return mockFile;
    });
  }

  static void reset() {
    _files.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileReceiverService service;
  late MockLogger mockLogger;
  late MockFile mockFile;

  setUp(() {
    MockFileFactory.reset();
    PathProviderPlatform.instance = MockPathProviderPlatform();
    mockLogger = MockLogger();
    mockFile = MockFile();

    // デフォルトのモック設定
    when(mockLogger.i(any,
            time: anyNamed('time'),
            error: anyNamed('error'),
            stackTrace: anyNamed('stackTrace')))
        .thenReturn(null);
    when(mockLogger.w(any,
            time: anyNamed('time'),
            error: anyNamed('error'),
            stackTrace: anyNamed('stackTrace')))
        .thenReturn(null);
    when(mockLogger.e(any,
            time: anyNamed('time'),
            error: anyNamed('error'),
            stackTrace: anyNamed('stackTrace')))
        .thenReturn(null);

    // ファイルの基本設定
    when(mockFile.path).thenReturn('/test/source/test.m4a');
    when(mockFile.exists()).thenAnswer((_) => Future.value(true));
    when(mockFile.readAsBytes())
        .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));

    service = FileReceiverService(
      logger: mockLogger,
    );

    // 初期化時のログ出力をverify
    verify(mockLogger.i('Initializing file receiver...',
            time: null, error: null, stackTrace: null))
        .called(1);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('FileReceiverService', () {
    test('ファイルのコピーが成功すること', () async {
      // コピー先のモックファイルを準備
      final mockDestFile = MockFile();
      when(mockDestFile.path).thenReturn('/test/path/newfile.m4a');
      when(mockDestFile.exists()).thenAnswer((_) => Future.value(false));
      when(mockDestFile.writeAsBytes(any, flush: true))
          .thenAnswer((_) => Future.value(mockDestFile));
      when(mockDestFile.readAsBytes())
          .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));

      // ソースファイルの設定
      when(mockFile.exists()).thenAnswer((_) => Future.value(true));
      when(mockFile.readAsBytes())
          .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));

      // File コンストラクタのモックを設定
      final result = await service.copyFileToDocuments(
        mockFile,
        'newfile.m4a',
        fileFactory: (path) => mockDestFile,
      );

      expect(result, '/test/path/newfile.m4a');
      verifyInOrder([
        mockLogger.i('File size before copy: 5 bytes',
            time: null, error: null, stackTrace: null),
        mockLogger.i('File size after copy: 5 bytes',
            time: null, error: null, stackTrace: null),
        mockLogger.i('File copied successfully: /test/path/newfile.m4a',
            time: null, error: null, stackTrace: null),
      ]);
    });

    test('ファイルのコピーが失敗した場合、例外をスローすること', () async {
      final expectedError = Exception('コピーエラー');
      when(mockFile.exists()).thenAnswer((_) => Future.value(true));
      when(mockFile.readAsBytes()).thenThrow(expectedError);

      await expectLater(
        () => service.copyFileToDocuments(mockFile, 'newfile.m4a',
            fileFactory: (path) => mockFile),
        throwsA(expectedError),
      );

      verify(mockLogger.e('Error copying file: $expectedError',
              time: null, error: null, stackTrace: null))
          .called(1);
    });

    test('音声ファイルを正しく処理できること', () async {
      final mockSharedFile = SharedMediaFile(
        path: 'test.m4a',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );
      var audioFileReceived = false;

      when(mockFile.exists()).thenAnswer((_) async => true);

      await service.processSharedFiles(
        [mockSharedFile],
        (file) async {
          audioFileReceived = true;
        },
        (file) async {},
        fileFactory: (path) => mockFile,
      );

      expect(audioFileReceived, true);
      verifyInOrder([
        mockLogger.i('Processing 1 files...',
            time: null, error: null, stackTrace: null),
        mockLogger.i('Processing file: test.m4a',
            time: null, error: null, stackTrace: null),
        mockLogger.i('File extension: m4a',
            time: null, error: null, stackTrace: null),
        mockLogger.i('Processing audio file: test.m4a',
            time: null, error: null, stackTrace: null),
      ]);
    });

    test('ログファイルを正しく処理できること', () async {
      final mockSharedFile = SharedMediaFile(
        path: 'test.log',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );
      var logFileReceived = false;

      final mockLogFile = MockFile();
      when(mockLogFile.path).thenReturn('test.log');
      when(mockLogFile.exists()).thenAnswer((_) async => true);
      when(mockLogFile.readAsBytes())
          .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));

      await service.processSharedFiles(
        [mockSharedFile],
        (file) async {},
        (file) async {
          logFileReceived = true;
        },
        fileFactory: (path) => mockLogFile,
      );

      expect(logFileReceived, true);
      verifyInOrder([
        mockLogger.i('Processing 1 files...',
            time: null, error: null, stackTrace: null),
        mockLogger.i('Processing file: test.log',
            time: null, error: null, stackTrace: null),
        mockLogger.i('File extension: log',
            time: null, error: null, stackTrace: null),
        mockLogger.i('Processing log file: test.log',
            time: null, error: null, stackTrace: null),
      ]);
    });

    test('未対応の拡張子のファイルを適切に処理できること', () async {
      final mockSharedFile = SharedMediaFile(
        path: 'test.pdf',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );

      final mockXyzFile = MockFile();
      when(mockXyzFile.path).thenReturn('test.pdf');
      when(mockXyzFile.exists()).thenAnswer((_) async => true);
      when(mockXyzFile.readAsBytes())
          .thenAnswer((_) => Future.value(Uint8List.fromList([1, 2, 3, 4, 5])));

      await service.processSharedFiles(
        [mockSharedFile],
        (file) async {},
        (file) async {},
        fileFactory: (path) => mockXyzFile,
      );

      verifyInOrder([
        mockLogger.i('Processing 1 files...',
            time: null, error: null, stackTrace: null),
        mockLogger.i('Processing file: test.pdf',
            time: null, error: null, stackTrace: null),
        mockLogger.i('File extension: pdf',
            time: null, error: null, stackTrace: null),
        mockLogger.w('Unsupported file extension: pdf',
            time: null, error: null, stackTrace: null),
      ]);
    });

    test('存在しないファイルを適切に処理できること', () async {
      final mockSharedFile = SharedMediaFile(
        path: 'test.m4a',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );

      when(mockFile.exists()).thenAnswer((_) async => false);

      await service.processSharedFiles(
        [mockSharedFile],
        (file) async {},
        (file) async {},
        fileFactory: (path) => mockFile,
      );

      verify(mockLogger.w('File does not exist: test.m4a',
              time: null, error: null, stackTrace: null))
          .called(1);
    });

    test('空のファイルパスを適切に処理できること', () async {
      final mockSharedFile = SharedMediaFile(
        path: '',
        type: SharedMediaType.file,
        thumbnail: null,
        duration: null,
      );

      await service.processSharedFiles(
        [mockSharedFile],
        (file) async {},
        (file) async {},
        fileFactory: (path) => mockFile,
      );

      verify(mockLogger.w('Empty file path',
              time: null, error: null, stackTrace: null))
          .called(1);
    });
  });
}
