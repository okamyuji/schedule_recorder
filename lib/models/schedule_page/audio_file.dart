import 'dart:io';

import 'package:path/path.dart';

/// 録音ファイルのモデル
class AudioFile {
  final String path;
  final String name;
  final DateTime createdAt;
  final bool isShared;

  /// 録音ファイルのモデルを作成する
  /// ファイルのパス、ファイル名、作成日時、共有フラグを指定する
  const AudioFile({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.isShared,
  });

  /// ファイルから録音ファイルのモデルを作成する
  /// ファイルのパスからファイル名を取得し、ファイルの作成日時を取得する
  factory AudioFile.fromFile(File file) {
    return AudioFile(
      path: file.path,
      name: basename(file.path),
      createdAt: file.statSync().changed,
      isShared: !file.path.contains('recording'),
    );
  }
}
