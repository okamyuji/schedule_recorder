// Dart imports:
import 'dart:io';

/// ファイルシステム操作のラッパークラス
class FileSystem {
  static FileSystem instance = FileSystem._();

  Directory Function(String) _directoryFactory = Directory.new;
  File Function(String) _fileFactory = File.new;

  FileSystem._();

  static void setDirectoryFactory(Directory Function(String) factory) {
    instance._directoryFactory = factory;
  }

  static void setFileFactory(File Function(String) factory) {
    instance._fileFactory = factory;
  }

  static void reset() {
    instance._directoryFactory = Directory.new;
    instance._fileFactory = File.new;
  }

  static Directory getDirectory(String path) =>
      instance._directoryFactory(path);
  static File getFile(String path) => instance._fileFactory(path);
}
