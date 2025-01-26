// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';

void main() {
  group('RecordingStateNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初期状態は停止', () {
      final state = container.read(recordingStateNotifierProvider);
      expect(state, equals(RecordingState.stopped));
    });

    test('startRecordingが録音状態に変更する', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      notifier.startRecording();
      expect(container.read(recordingStateNotifierProvider),
          equals(RecordingState.recording));
    });

    test('pauseRecordingが一時停止状態に変更する', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      notifier.startRecording();
      notifier.pauseRecording();
      expect(container.read(recordingStateNotifierProvider),
          equals(RecordingState.paused));
    });

    test('resumeRecordingが録音状態に変更する', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      notifier.startRecording();
      notifier.pauseRecording();
      notifier.resumeRecording();
      expect(container.read(recordingStateNotifierProvider),
          equals(RecordingState.recording));
    });

    test('stopRecordingが停止状態に変更する', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      notifier.startRecording();
      notifier.stopRecording();
      expect(container.read(recordingStateNotifierProvider),
          equals(RecordingState.stopped));
    });

    test('isRecordingが正しく状態を返す', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      expect(notifier.isRecording(), isFalse);
      notifier.startRecording();
      expect(notifier.isRecording(), isTrue);
      notifier.pauseRecording();
      expect(notifier.isRecording(), isFalse);
    });

    test('isPausedが正しく状態を返す', () {
      final notifier = container.read(recordingStateNotifierProvider.notifier);
      expect(notifier.isPaused(), isFalse);
      notifier.startRecording();
      expect(notifier.isPaused(), isFalse);
      notifier.pauseRecording();
      expect(notifier.isPaused(), isTrue);
      notifier.resumeRecording();
      expect(notifier.isPaused(), isFalse);
    });
  });
}
