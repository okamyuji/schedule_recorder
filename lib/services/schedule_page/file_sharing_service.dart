import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ファイル共有機能を提供するサービスクラス
class FileSharingService {
  final Logger _logger;

  /// コンストラクタ
  ///
  /// [logger] - ロギング用のインスタンス
  const FileSharingService({
    required Logger logger,
  }) : _logger = logger;

  /// 録音ファイルを共有する
  ///
  /// [context] - BuildContext
  ///
  /// 共有に失敗した場合は[ShareFilesException]をスローする
  Future<void> shareFiles({
    required BuildContext context,
  }) async {
    try {
      _logger.w('ファイル共有を開始します');
      final appDir = await getApplicationDocumentsDirectory();
      final recordingPath = path.join(appDir.path, 'recording.m4a');
      final recordingFile = File(recordingPath);

      if (!recordingFile.existsSync()) {
        _logger.e('共有可能なファイルが見つかりません');
        throw const ShareFilesException('共有できるファイルがありません');
      }

      final files = <XFile>[];

      // 録音ファイルの追加
      if (recordingFile.existsSync()) {
        _logger.w('録音ファイルを共有リストに追加: $recordingPath');
        files.add(XFile(recordingPath, mimeType: 'audio/mp4'));
      }

      await Share.shareXFiles(
        files,
        subject: '録音データ',
      );
      _logger.w('ファイル共有が完了しました');
    } catch (e) {
      _logger.e('ファイル共有に失敗しました: $e');
      throw ShareFilesException('ファイルの共有に失敗しました: $e');
    }
  }
}

/// ファイル共有時の例外
class ShareFilesException implements Exception {
  final String message;

  const ShareFilesException(this.message);

  @override
  String toString() => message;
}
