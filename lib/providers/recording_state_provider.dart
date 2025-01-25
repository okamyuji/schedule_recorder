import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recording_state_provider.g.dart';

/// 録音状態
enum RecordingState {
  stopped,
  recording,
  paused,
}

/// 録音状態のプロバイダ
@riverpod
class RecordingStateNotifier extends _$RecordingStateNotifier {
  @override
  RecordingState build() => RecordingState.stopped;

  void startRecording() {
    state = RecordingState.recording;
  }

  /// 録音を一時停止する
  void pauseRecording() {
    if (state == RecordingState.recording) {
      state = RecordingState.paused;
    }
  }

  /// 録音を再開する
  void resumeRecording() {
    if (state == RecordingState.paused) {
      state = RecordingState.recording;
    }
  }

  /// 録音を停止する
  void stopRecording() {
    state = RecordingState.stopped;
  }
}
