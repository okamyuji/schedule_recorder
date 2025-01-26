// Package imports:
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 共有された音声ファイルのモデル
class SharedAudioFile {
  final String path;
  final String mimeType;
  final DateTime timestamp;

  const SharedAudioFile({
    required this.path,
    required this.mimeType,
    required this.timestamp,
  });

  /// 共有されたメディアファイルからSharedAudioFileを生成する
  factory SharedAudioFile.fromSharedMediaFile(SharedMediaFile file) {
    return SharedAudioFile(
      path: file.path,
      mimeType: file.mimeType ?? 'audio/*',
      timestamp: DateTime.now(),
    );
  }

  /// 共有されたメディアファイルが音声ファイルかどうかを返す
  bool get isAudioFile {
    return mimeType.startsWith('audio/') ||
        path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.wav');
  }
}
