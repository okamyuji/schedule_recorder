// Dart imports:
import 'dart:async';

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
        _record = recorder;

  /// 録音を再開する
  Future<void> resumeRecording() async {
    try {
      _log.i('録音再開を試みています...');

      // 現在のオーディオセッション状態をチェック
      bool isCallActive = await _methodChannel.invokeMethod('IsSIPCallActive');
      if (isCallActive) {
        _log.w('SIP通話が進行中のため、録音を再開できません');
        return;
      }

      // 一時停止状態を確認
      if (_recordState != RecordState.pause) {
        _log.w('録音が一時停止状態ではないため再開できません。現在の状態: $_recordState');
        return;
      }

      // デバイスの状態をチェック
      var deviceInfo = await _methodChannel.invokeMethod('GetAudioDeviceInfo');
      _log.i('再開前のオーディオデバイス情報: $deviceInfo');

      await _record?.resume();
      _recordState = RecordState.record;
      _log.i('録音を再開しました');

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
        _log.w('録音を停止できません - 録音状態ではありません');
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
    recordStateStreamController.close();
    _record?.dispose();
  }
}
