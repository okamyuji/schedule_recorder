// Dart imports:
import 'dart:io';

// Package imports:
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:schedule_recorder/models/schedule_page/audio_file.dart';
import 'package:schedule_recorder/services/schedule_page/file_system.dart';

/// ファイル管理サービス
class FileManagementService {
  final Logger _logger;
  final String _documentsPath;

  /// ファイル管理サービスを作成する
  /// ロガーとドキュメントパスを指定する
  FileManagementService({
    required Logger logger,
    required String documentsPath,
  })  : _logger = logger,
        _documentsPath = documentsPath;

  /// ドキュメントパスにある音声ファイルを取得する
  /// 音声ファイルのパスが.m4a, .mp3, .wavのいずれかで終わるファイルを取得する
  /// 取得した音声ファイルをAudioFileのリストに変換して返す
  /// エラーが発生した場合はエラーを返す
  Future<List<AudioFile>> getAudioFiles() async {
    try {
      final directory = FileSystem.getDirectory(_documentsPath);
      final files = await directory
          .list()
          .where((entity) =>
              entity is File &&
              (entity.path.endsWith('.m4a') ||
                  entity.path.endsWith('.mp3') ||
                  entity.path.endsWith('.wav')))
          .map((file) => AudioFile.fromFile(file as File))
          .toList();

      _logger.i('${files.length} 個の音声ファイルが検出されました');
      return files;
    } catch (e) {
      _logger.e('ファイル一覧の取得に失敗しました: $e');
      rethrow;
    }
  }

  /// ファイルを削除する
  /// ファイルのパスを指定してファイルを削除する
  /// エラーが発生した場合はエラーを返す
  Future<void> deleteFile(String path) async {
    try {
      final file = FileSystem.getFile(path);
      await file.delete();
      _logger.i('ファイルを削除しました: $path');
    } catch (e) {
      _logger.e('ファイルの削除に失敗しました: $path, エラー: $e');
      rethrow;
    }
  }

  /// 共有された音声ファイルのパスを指定してファイルをインポートする
  /// エラーが発生した場合はエラーを返す
  /// インポートしたファイルのパスを返す
  Future<void> importSharedAudioFile(String sourcePath) async {
    final fileName = path.basename(sourcePath);
    final targetPath = path.join(_documentsPath, fileName);

    try {
      await File(sourcePath).copy(targetPath);
      _logger.i('音声ファイルをインポートしました: $targetPath');
    } catch (e) {
      _logger.e('音声ファイルのインポートに失敗しました: $e');
      throw Exception('音声ファイルのインポートに失敗しました: $e');
    }
  }
}
