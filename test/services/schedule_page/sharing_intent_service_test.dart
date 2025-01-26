// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// Project imports:
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/services/schedule_page/sharing_intent_service.dart';

class MockLogger extends Mock implements Logger {}

class MockFileManagementService extends Mock implements FileManagementService {}

class MockSharedMediaFile extends Mock implements SharedMediaFile {}

// プラットフォームインターフェースのモックを正しく実装
class MockReceiveSharingIntent extends Mock
    with MockPlatformInterfaceMixin
    implements ReceiveSharingIntent {
  static final _instance = MockReceiveSharingIntent._();
  MockReceiveSharingIntent._();

  factory MockReceiveSharingIntent() => _instance;
}

void main() {
  group('SharingIntentService Tests', () {
    late SharingIntentService service;
    late MockLogger mockLogger;
    late MockFileManagementService mockFileManagementService;
    late StreamController<List<SharedMediaFile>> mediaStreamController;
    late MockReceiveSharingIntent mockReceiveSharingIntent;

    setUp(() {
      mockLogger = MockLogger();
      mockFileManagementService = MockFileManagementService();
      mediaStreamController = StreamController<List<SharedMediaFile>>();

      // ReceiveSharingIntentのモックセットアップ
      mockReceiveSharingIntent = MockReceiveSharingIntent();
      ReceiveSharingIntent.instance = mockReceiveSharingIntent;

      when(() => mockReceiveSharingIntent.getMediaStream())
          .thenAnswer((_) => mediaStreamController.stream);
      when(() => mockReceiveSharingIntent.getInitialMedia())
          .thenAnswer((_) async => <SharedMediaFile>[]);
      when(() => mockReceiveSharingIntent.reset()).thenAnswer((_) async {});

      // Loggerのモックセットアップ
      when(() => mockLogger.i(any())).thenReturn(null);
      when(() => mockLogger.w(any())).thenReturn(null);
      when(() => mockLogger.e(any())).thenReturn(null);

      service = SharingIntentService(
        logger: mockLogger,
        fileManagementService: mockFileManagementService,
      );
    });

    tearDown(() {
      mediaStreamController.close();
    });

    test('initializeが正常に初期化を完了する', () async {
      // act
      await service.initialize();

      // assert
      verify(() => mockLogger.i('共有インテントサービスの初期化を開始します')).called(1);
      verify(() => mockLogger.i('共有インテントサービスの初期化が完了しました')).called(1);
      verify(() => mockReceiveSharingIntent.getInitialMedia()).called(1);
    });

    test('初期共有メディアが存在する場合に正しく処理される', () async {
      // arrange
      final mockSharedFile = MockSharedMediaFile();
      when(() => mockSharedFile.path).thenReturn('/test/audio.m4a');
      when(() => mockSharedFile.mimeType).thenReturn('audio/mp4');
      when(() => mockReceiveSharingIntent.getInitialMedia())
          .thenAnswer((_) async => [mockSharedFile]);
      when(() => mockFileManagementService.importSharedAudioFile(any()))
          .thenAnswer((_) async {});

      // act
      await service.initialize();

      // assert
      verify(() => mockFileManagementService.importSharedAudioFile(any()))
          .called(1);
      verify(() => mockLogger.i('音声ファイルのインポートが完了しました: /test/audio.m4a'))
          .called(1);
    });

    test('共有ストリームが新しいファイルを受信したときに正しく処理される', () async {
      // arrange
      final mockSharedFile = MockSharedMediaFile();
      when(() => mockSharedFile.path).thenReturn('/test/audio.m4a');
      when(() => mockSharedFile.mimeType).thenReturn('audio/mp4');
      when(() => mockFileManagementService.importSharedAudioFile(any()))
          .thenAnswer((_) async {});

      // act
      await service.initialize();
      mediaStreamController.add([mockSharedFile]);
      await Future.delayed(const Duration(milliseconds: 100));

      // assert
      verify(() => mockFileManagementService.importSharedAudioFile(any()))
          .called(1);
      verify(() => mockLogger.i('音声ファイルのインポートが完了しました: /test/audio.m4a'))
          .called(1);
    });

    test('非対応のファイル形式は処理をスキップする', () async {
      // arrange
      final mockSharedFile = MockSharedMediaFile();
      when(() => mockSharedFile.path).thenReturn('/test/document.pdf');
      when(() => mockSharedFile.mimeType).thenReturn('application/pdf');

      // act
      await service.initialize();
      mediaStreamController.add([mockSharedFile]);
      await Future.delayed(const Duration(milliseconds: 100));

      // assert
      verify(() => mockLogger.w('非対応のファイル形式です: application/pdf')).called(1);
      verifyNever(() => mockFileManagementService.importSharedAudioFile(any()));
    });

    test('ファイル処理中にエラーが発生した場合適切にハンドリングされる', () async {
      // arrange
      final mockSharedFile = MockSharedMediaFile();
      when(() => mockSharedFile.path).thenReturn('/test/audio.m4a');
      when(() => mockSharedFile.mimeType).thenReturn('audio/mp4');
      when(() => mockFileManagementService.importSharedAudioFile(any()))
          .thenThrow(Exception('Import failed'));

      // act
      await service.initialize();
      mediaStreamController.add([mockSharedFile]);
      await Future.delayed(const Duration(milliseconds: 100));

      // assert
      verify(() =>
              mockLogger.e('ファイルの処理中にエラーが発生しました: Exception: Import failed'))
          .called(1);
    });
  });
}
