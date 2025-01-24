import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 他のアプリからファイルを受け取る機能を提供するサービスクラス
class FileReceiverService {
  final Logger _logger;
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  Function(File)? _onAudioFileReceived;
  Function(File)? _onLogFileReceived;

  /// コンストラクタ
  ///
  /// [logger] - ロギング用のインスタンス
  FileReceiverService({
    required Logger logger,
  }) : _logger = logger {
    _initializeReceiver();
  }

  /// 受信機能の初期化
  void _initializeReceiver() {
    _logger.i('Initializing file receiver...');

    // 初期共有を監視
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      _logger.i('Initial shared files: ${files.length}');
      if (files.isNotEmpty &&
          _onAudioFileReceived != null &&
          _onLogFileReceived != null) {
        processSharedFiles(files, _onAudioFileReceived!, _onLogFileReceived!);
      }
    }).catchError((error) {
      _logger.e('Error getting initial media: $error');
    });

    // ストリームでの共有を監視
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
      _logger.i('Stream shared files: ${files.length}');
      if (files.isNotEmpty &&
          _onAudioFileReceived != null &&
          _onLogFileReceived != null) {
        processSharedFiles(files, _onAudioFileReceived!, _onLogFileReceived!);
      }
    }, onError: (error) {
      _logger.e('Error receiving files: $error');
    }, cancelOnError: false);
  }

  /// 共有されたファイルを処理する
  ///
  /// [onAudioFileReceived] - 音声ファイルを受け取った時のコールバック
  /// [onLogFileReceived] - ログファイルを受け取った時のコールバック
  Future<void> handleSharedFiles({
    required Function(File) onAudioFileReceived,
    required Function(File) onLogFileReceived,
    File Function(String)? fileFactory,
  }) async {
    _logger.i('Setting up file handlers...');
    _onAudioFileReceived = onAudioFileReceived;
    _onLogFileReceived = onLogFileReceived;
  }

  /// 共有されたファイルを個別に処理する
  ///
  /// [files] 共有されたファイルのリスト
  /// [onAudioFileReceived] 音声ファイルを受信した際のコールバック
  /// [onLogFileReceived] ログファイルを受信した際のコールバック
  /// [fileFactory] ファイルの生成をカスタマイズするためのオプションのファクトリ関数
  ///
  /// 各ファイルの拡張子に応じて音声ファイル・ログファイルの処理を振り分ける。それ以外の拡張子に対しては警告をログに出力する。
  /// ファイルが存在しない場合や処理に失敗した場合は、エラーログを出力し例外をスローする。
  Future<void> processSharedFiles(
    List<SharedMediaFile> files,
    Function(File) onAudioFileReceived,
    Function(File) onLogFileReceived, {
    File Function(String)? fileFactory,
  }) async {
    _logger.i('Processing ${files.length} files...');

    for (final file in files) {
      final filePath = file.path;
      _logger.i('Processing file: $filePath');

      if (filePath.isEmpty) {
        _logger.w('Empty file path');
        continue;
      }

      final extension =
          path.extension(filePath).toLowerCase().replaceAll('.', '');
      _logger.i('File extension: $extension');

      try {
        final sourceFile = fileFactory?.call(filePath) ?? File(filePath);
        if (!await sourceFile.exists()) {
          _logger.w('File does not exist: $filePath');
          continue;
        }

        if (['m4a', 'mp3', 'wav'].contains(extension)) {
          _logger.i('Processing audio file: $filePath');
          await onAudioFileReceived(sourceFile);
        } else if (['txt', 'log'].contains(extension)) {
          _logger.i('Processing log file: $filePath');
          await onLogFileReceived(sourceFile);
        } else {
          _logger.w('Unsupported file extension: $extension');
        }
      } catch (e) {
        _logger.e('Error processing file: $e, path: $filePath');
        rethrow;
      }
    }
  }

  /// 共有されたファイルをアプリのドキュメントディレクトリにコピーする
  ///
  /// [file] - コピーするファイル
  /// [newFileName] - 新しいファイル名（拡張子を含む）
  /// [fileFactory] - ファイルの生成をカスタマイズするためのオプションのファクトリ関数
  /// 戻り値: コピーされたファイルのパス
  Future<String> copyFileToDocuments(
    File file,
    String newFileName, {
    File Function(String)? fileFactory,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = path.join(appDir.path, newFileName);
      final newFile = fileFactory?.call(newPath) ?? File(newPath);

      // ファイルが既に存在する場合は削除
      if (await newFile.exists()) {
        await newFile.delete();
      }

      // ファイルの内容を読み取り
      final contents = await file.readAsBytes();
      _logger.i('File size before copy: ${contents.length} bytes');

      if (contents.isEmpty) {
        throw Exception('Source file is empty');
      }

      // 新しいファイルに書き込み
      await newFile.writeAsBytes(contents, flush: true);

      // コピー後のサイズを確認
      final copiedContents = await newFile.readAsBytes();
      _logger.i('File size after copy: ${copiedContents.length} bytes');

      if (copiedContents.isEmpty) {
        throw Exception('Copied file is empty');
      }

      _logger.i('File copied successfully: $newPath');
      return newPath;
    } catch (e) {
      _logger.e('Error copying file: $e');
      rethrow;
    }
  }

  /// リソースの解放
  Future<void> dispose() async {
    _logger.i('Disposing file receiver...');
    await _subscription?.cancel();
    _onAudioFileReceived = null;
    _onLogFileReceived = null;
  }
}
