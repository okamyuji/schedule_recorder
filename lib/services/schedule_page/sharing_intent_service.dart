// Dart imports:
import 'dart:async';

// Package imports:
import 'package:logger/logger.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// Project imports:
import 'package:schedule_recorder/models/schedule_page/shared_audio_file.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';

/// 共有インテントサービス
class SharingIntentService {
  final Logger _logger;
  final FileManagementService _fileManagementService;
  StreamSubscription? _intentDataStreamSubscription;

  SharingIntentService({
    required Logger logger,
    required FileManagementService fileManagementService,
  })  : _logger = logger,
        _fileManagementService = fileManagementService;

  /// 共有インテントサービスを初期化する
  /// エラーが発生した場合はエラーを返す
  Future<void> initialize() async {
    _logger.i('共有インテントサービスの初期化を開始します');

    // アプリが起動していない状態で共有された場合の処理
    try {
      _logger.d('初期共有メディアの取得を開始します');
      final initialMedia =
          await ReceiveSharingIntent.instance.getInitialMedia();
      _logger.d('初期共有メディアの取得が完了しました: ${initialMedia.length}件');
      if (initialMedia.isNotEmpty) {
        await _processSharedFiles(initialMedia);
      }
    } catch (e) {
      _logger.e('初期共有メディアの処理中にエラーが発生しました: $e');
    }

    // アプリ起動中に共有された場合の処理
    _logger.d('共有インテントストリームのリスナーを設定します');
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        _logger.d('共有インテントストリームからファイルを受信しました: ${files.length}件');
        _processSharedFiles(files);
      },
      onError: (error) {
        _logger.e('共有インテントストリームでエラーが発生しました: $error');
      },
    );

    _logger.i('共有インテントサービスの初期化が完了しました');
  }

  /// 共有ファイルの処理を行う
  /// エラーが発生した場合はエラーを返す
  Future<void> _processSharedFiles(List<SharedMediaFile> sharedFiles) async {
    _logger.i('共有ファイルの処理を開始します: ${sharedFiles.length}件');

    for (final sharedFile in sharedFiles) {
      try {
        _logger.d(
            '共有ファイルの処理: ${sharedFile.path}, MIMEタイプ: ${sharedFile.mimeType}');
        final audioFile = SharedAudioFile.fromSharedMediaFile(sharedFile);

        if (!audioFile.isAudioFile) {
          _logger.w('非対応のファイル形式です: ${audioFile.mimeType}');
          continue;
        }

        await _fileManagementService.importSharedAudioFile(audioFile.path);
        _logger.i('音声ファイルのインポートが完了しました: ${audioFile.path}');
      } catch (e) {
        _logger.e('ファイルの処理中にエラーが発生しました: $e');
      }
    }

    // 処理完了後にインテントをリセット
    _logger.d('共有インテントをリセットします');
    ReceiveSharingIntent.instance.reset();
  }

  /// 共有インテントサービスを破棄する
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _logger.i('共有インテントサービスを破棄しました');
  }
}
