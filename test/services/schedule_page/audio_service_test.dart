// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

// Project imports:
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';

class MockLogger extends Mock implements Logger {}

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockRecordingStateNotifier extends Mock
    implements RecordingStateNotifier {}

class MockAudioRecorder extends Mock implements AudioRecorder {
  final _stateController = StreamController<RecordState>.broadcast();

  @override
  Stream<RecordState> onStateChanged() => _stateController.stream;

  void emitState(RecordState state) {
    _stateController.add(state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

class MockAudioServiceNotifier extends Mock implements AudioServiceNotifier {}

class MockMethodChannel extends Mock implements MethodChannel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService Tests', () {
    late AudioService audioService;
    late MockLogger mockLogger;
    late MockAudioPlayer mockPlayer;
    late MockRecordingStateNotifier mockRecordingStateNotifier;
    late MockAudioRecorder mockRecorder;
    late MockAudioServiceNotifier mockAudioServiceNotifier;
    late MockMethodChannel mockMethodChannel;

    setUp(() {
      mockLogger = MockLogger();
      mockPlayer = MockAudioPlayer();
      mockRecordingStateNotifier = MockRecordingStateNotifier();
      mockRecorder = MockAudioRecorder();
      mockAudioServiceNotifier = MockAudioServiceNotifier();
      mockMethodChannel = MockMethodChannel();

      registerFallbackValue(const RecordConfig());

      audioService = AudioService(
        player: mockPlayer,
        logger: mockLogger,
        recordingStateNotifier: mockRecordingStateNotifier,
        recorder: mockRecorder,
        audioServiceNotifier: mockAudioServiceNotifier,
      );
    });

    tearDown(() async {
      await mockRecorder.dispose();
    });

    test('startRecordingが正常に録音を開始する', () async {
      // arrange
      const testPath = 'test/path/recording.m4a';
      when(() => mockRecorder.start(any(), path: testPath))
          .thenAnswer((_) => Future.value());

      // act
      await audioService.startRecording(testPath);

      // assert
      verify(() => mockAudioServiceNotifier.setCurrentRecordingPath(testPath))
          .called(1);
      verify(() => mockRecorder.start(any(), path: testPath)).called(1);
      verify(() => mockLogger.i(any())).called(2);
    });

    test('pauseRecordingが録音を正常に一時停止する', () async {
      // arrange
      when(() => mockAudioServiceNotifier.recordState)
          .thenReturn(RecordState.record);
      when(() => mockRecorder.pause()).thenAnswer((_) => Future.value());

      // act
      await audioService.pauseRecording();

      // assert
      verify(() => mockRecorder.pause()).called(1);
      verify(() => mockLogger.i(any())).called(3);
    });

    test('resumeRecordingが録音を正常に再開する', () async {
      // arrange
      when(() => mockAudioServiceNotifier.recordState)
          .thenReturn(RecordState.pause);
      when(() => mockRecorder.resume()).thenAnswer((_) => Future.value());

      // act
      await audioService.resumeRecording();

      // assert
      verify(() => mockRecorder.resume()).called(1);
      verify(() => mockLogger.i(any())).called(3);
    });

    test('stopRecordingが録音を正常に停止する', () async {
      // arrange
      when(() => mockRecorder.isRecording())
          .thenAnswer((_) => Future.value(true));
      when(() => mockRecorder.stop())
          .thenAnswer((_) => Future.value('test/path/recording.m4a'));

      // act
      await audioService.stopRecording();

      // assert
      verify(() => mockRecorder.stop()).called(1);
      verify(() => mockLogger.i(any())).called(3);
    });

    test('startPlayingが正常に再生を開始する', () async {
      // arrange
      const testPath = 'test/path/recording.m4a';
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) => Future.value());
      when(() => mockPlayer.setFilePath(any()))
          .thenAnswer((_) => Future.value());
      when(() => mockPlayer.play()).thenAnswer((_) => Future.value());

      // act
      await audioService.startPlaying(testPath);

      // assert
      verify(() => mockPlayer.setVolume(1.0)).called(1);
      verify(() => mockPlayer.setFilePath(testPath)).called(1);
      verify(() => mockPlayer.play()).called(1);
      verify(() => mockLogger.i(any())).called(2);
    });

    test('setupNativeListenersが録音中断を正常に処理する', () async {
      // arrange
      when(() => mockMethodChannel.invokeMethod<bool>('isPhoneCallActive'))
          .thenAnswer((_) => Future.value(true));
      when(() => mockAudioServiceNotifier.recordState)
          .thenReturn(RecordState.record);
      when(() => mockRecorder.pause()).thenAnswer((_) => Future.value());

      // act
      audioService.setupNativeListeners();
      mockRecorder.emitState(RecordState.pause);
      await Future.delayed(const Duration(milliseconds: 100));

      // assert
      verifyNever(() => mockLogger.e(any()));
      verify(() => mockLogger.i(any())).called(1);
    });

    test('録音状態の変更が正しく通知される', () async {
      // arrange
      when(() => mockAudioServiceNotifier.recordState)
          .thenReturn(RecordState.record);

      // act
      mockRecorder.emitState(RecordState.pause);
      await Future.delayed(const Duration(milliseconds: 100));

      // assert
      verify(() =>
              mockAudioServiceNotifier.updateRecordState(RecordState.pause))
          .called(1);
      verify(() => mockLogger.i(any())).called(1);
    });
  });
}
