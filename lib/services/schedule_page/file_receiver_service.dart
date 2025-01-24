import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 他のアプリからファイルを受け取る機能を提供するサービスクラス
class FileReceiverService {
  final Logger _logger;

  /// コンストラクタ
  ///
  /// [logger] - ロギング用のインスタンス
  FileReceiverService({
    required Logger logger,
  }) : _logger = logger;

  /// 共有されたファイルを処理する
  ///
  /// [onAudioFileReceived] - 音声ファイルを受け取った時のコールバック
  /// [onLogFileReceived] - ログファイルを受け取った時のコールバック
  void handleSharedFiles({
    required Function(File file) onAudioFileReceived,
    required Function(File file) onLogFileReceived,
  }) {
    // 初期共有を処理
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      processSharedFiles(value, onAudioFileReceived, onLogFileReceived);
      // 処理完了後にリセット
      ReceiveSharingIntent.instance.reset();
    });

    // 新しい共有を監視
    ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      processSharedFiles(value, onAudioFileReceived, onLogFileReceived);
    });
  }

  Future<void> processSharedFiles(
    List<SharedMediaFile> files,
    Function(File file) onAudioFileReceived,
    Function(File file) onLogFileReceived,
  ) async {
    _logger.i('共有されたファイルの処理を開始: ${files.length}個のファイル');

    for (final file in files) {
      final extension = path.extension(file.path).toLowerCase();
      final newFile = File(file.path);

      if (extension == '.m4a' || extension == '.mp3' || extension == '.wav') {
        _logger.i('音声ファイルを受信: ${file.path}');
        onAudioFileReceived(newFile);
      } else if (extension == '.txt' || extension == '.log') {
        _logger.i('ログファイルを受信: ${file.path}');
        onLogFileReceived(newFile);
      } else {
        _logger.w('未対応のファイル形式: ${file.path}');
      }
    }
  }

  /// 共有されたファイルをアプリのドキュメントディレクトリにコピーする
  ///
  /// [file] - コピーするファイル
  /// [newFileName] - 新しいファイル名（拡張子を含む）
  ///
  /// 戻り値: コピーされたファイルのパス
  Future<String> copyFileToDocuments(File file, String newFileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = path.join(appDir.path, newFileName);

      await file.copy(newPath);
      _logger.i('ファイルをコピーしました: $newPath');

      return newPath;
    } catch (e) {
      _logger.e('ファイルのコピーに失敗: $e');
      rethrow;
    }
  }
}
