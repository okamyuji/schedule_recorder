// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';
// Package imports:
import 'package:logger/logger.dart';
import 'package:record/record.dart';

/// オーディオサービス（旧バージョン）
/// この実装はスケジュールページのオーディオサービスに移行されました。
/// 互換性のために残してありますが、新しい機能は schedule_page/audio_service.dart に実装してください。
class AudioService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.schedule_recorder/audio');

  final Logger _log;
  final AudioRecorder? _record;
  RecordState _recordState = RecordState.stop;
  final StreamController<RecordState> recordStateStreamController =
      StreamController<RecordState>.broadcast();

  AudioService({required Logger logger, AudioRecorder? recorder})
      : _log = logger,
        _record = recorder {
    // ネイティブプラットフォームからのメソッド呼び出しを処理するハンドラを設定
    _setupMethodCallHandler();
  }

  // ネイティブからのメソッド呼び出しハンドラの設定
  void _setupMethodCallHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'RecordingInterrupted':
          _log.i('録音中断イベントを受信しました');
          if (_recordState == RecordState.record) {
            await pauseRecording();
          }
          return null;
        case 'RecordingResumed':
          _log.i('録音再開イベントを受信しました');
          if (_recordState == RecordState.pause) {
            await resumeRecording();
          }
          return null;
        case 'GetRecordState':
          _log.i('録音状態が要求されました');
          return _recordState.name;
        case 'LogDebugMessage':
          _log.d('ネイティブログ: ${call.arguments}');
          return null;
        default:
          _log.w('未知のメソッド呼び出し: ${call.method}');
          return null;
      }
    });
  }

  /// 録音を再開する
  Future<void> resumeRecording() async {
    try {
      _log.i('録音再開を試みています...');

      // 一時停止状態を確認
      if (_recordState != RecordState.pause) {
        _log.w('録音が一時停止状態ではないため再開できません。現在の状態: $_recordState');
        return;
      }

      // iOSの場合は直接録音再開をネイティブ側に要求
      if (Platform.isIOS) {
        try {
          await _methodChannel.invokeMethod('directlyResumeRecording');
          _log.i('iOSネイティブ側に録音再開を要求しました');
        } catch (e) {
          _log.e('iOSネイティブ側での録音再開に失敗しました: $e');
          rethrow;
        }
      } else {
        await _record?.resume();
        _recordState = RecordState.record;
        _log.i('録音を再開しました');
      }

      // 通知を送信
      recordStateStreamController.add(_recordState);
    } catch (e) {
      _log.e('録音再開中にエラーが発生しました: $e');
      _recordState = RecordState.stop;
      recordStateStreamController.add(_recordState);
      rethrow;
    }
  }

  /// 録音を開始する
  Future<void> startRecording(String path) async {
    try {
      _log.i('録音を開始します: $path');

      // iOSの場合はオーディオセッションを設定
      if (Platform.isIOS) {
        try {
          await _methodChannel.invokeMethod('configureAudioSession');
          _log.i('オーディオセッションを設定しました');
        } catch (e) {
          _log.w('オーディオセッション設定中にエラーが発生しました: $e');
        }
      }

      await _record?.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _recordState = RecordState.record;
      recordStateStreamController.add(_recordState);
      _log.i('録音が開始されました');
    } catch (e) {
      _log.e('録音の開始に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音を一時停止する
  Future<void> pauseRecording() async {
    try {
      _log.i('録音を一時停止します');
      if (_recordState == RecordState.record) {
        await _record?.pause();
        _recordState = RecordState.pause;
        recordStateStreamController.add(_recordState);
        _log.i('録音が一時停止されました');
      } else {
        _log.w('録音を一時停止できません - 録音状態ではありません');
      }
    } catch (e) {
      _log.e('録音の一時停止に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音を停止する
  Future<String?> stopRecording() async {
    try {
      _log.i('録音を停止します');
      String? path;
      if (_recordState == RecordState.record ||
          _recordState == RecordState.pause) {
        path = await _record?.stop();
        _recordState = RecordState.stop;
        recordStateStreamController.add(_recordState);
        _log.i('録音が停止されました: $path');
      } else {
        _log.w('録音を停止できません - すでに停止しています');
      }
      return path;
    } catch (e) {
      _log.e('録音の停止に失敗しました: $e');
      rethrow;
    }
  }

  /// 録音状態を取得する
  RecordState getRecordState() {
    return _recordState;
  }

  /// リソースの解放
  void dispose() {
    _record?.dispose();
    recordStateStreamController.close();
  }
}
