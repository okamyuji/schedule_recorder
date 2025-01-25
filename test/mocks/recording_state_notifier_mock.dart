import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';

class MockRecordingStateNotifier extends AutoDisposeNotifier<RecordingState>
    with Mock
    implements RecordingStateNotifier {
  RecordingState _state = RecordingState.stopped;

  @override
  RecordingState build() => _state;

  @override
  RecordingState get state => _state;

  @override
  set state(RecordingState value) {
    _state = value;
  }

  @override
  void startRecording() {
    _state = RecordingState.recording;
  }

  @override
  void pauseRecording() {
    _state = RecordingState.paused;
  }

  @override
  void stopRecording() {
    _state = RecordingState.stopped;
  }
}
