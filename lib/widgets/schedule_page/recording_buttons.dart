import 'package:flutter/material.dart';
import 'package:schedule_recorder/constants/strings.dart';

class RecordingButtons extends StatelessWidget {
  final bool isRecording;
  final bool isPlaying;
  final bool isPaused;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onStartPlaying;
  final VoidCallback? onStopPlaying;
  final VoidCallback? onPauseRecording;
  final VoidCallback? onResumeRecording;

  /// コンストラクタ
  ///
  /// [isRecording] - 録音中かどうか
  /// [isPlaying] - 再生中かどうか
  /// [isPaused] - 一時停止中かどうか
  /// [onStartRecording] - 録音開始時のコールバック
  /// [onStopRecording] - 録音停止時のコールバック
  /// [onStartPlaying] - 再生開始時のコールバック
  /// [onStopPlaying] - 再生停止時のコールバック
  /// [onPauseRecording] - 録音一時停止時のコールバック
  /// [onResumeRecording] - 録音再開時のコールバック
  const RecordingButtons({
    super.key,
    required this.isRecording,
    required this.isPlaying,
    required this.isPaused,
    this.onStartRecording,
    this.onStopRecording,
    this.onStartPlaying,
    this.onStopPlaying,
    this.onPauseRecording,
    this.onResumeRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 録音開始ボタン
        IconButton(
          key: const Key('record_button'),
          icon: const Icon(Icons.mic),
          color: isRecording ? Colors.red : Colors.black,
          onPressed: !isRecording ? onStartRecording : null,
          iconSize: 50,
          tooltip: Strings.recordingStartTooltip,
        ),
        // 録音一時停止/再開ボタン
        if (isRecording)
          IconButton(
            key: isPaused
                ? const Key('resume_button')
                : const Key('pause_button'),
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            color: Colors.red,
            onPressed: isPaused ? onResumeRecording : onPauseRecording,
            iconSize: 50,
            tooltip: isPaused
                ? Strings.recordingResumeTooltip
                : Strings.recordingPauseTooltip,
          ),
        // 録音停止ボタン
        IconButton(
          key: const Key('record_stop_button'),
          icon: const Icon(Icons.stop),
          color: isRecording ? Colors.red : Colors.black,
          onPressed: isRecording ? onStopRecording : null,
          iconSize: 50,
          tooltip: Strings.recordingStopTooltip,
        ),
        const SizedBox(width: 10),
        // 再生開始ボタン
        IconButton(
          key: const Key('play_button'),
          icon: const Icon(Icons.play_arrow),
          color: isPlaying ? Colors.green : Colors.black,
          iconSize: 50,
          onPressed:
              isRecording ? null : (isPlaying ? onStopPlaying : onStartPlaying),
          tooltip: Strings.recordingPlayTooltip,
        ),
        // 再生停止ボタン
        IconButton(
          key: const Key('stop_button'),
          icon: const Icon(Icons.stop),
          color: isPlaying ? Colors.green : Colors.black,
          onPressed: isPlaying ? onStopPlaying : null,
          tooltip: Strings.recordingPlayStopTooltip,
          iconSize: 50,
        ),
      ],
    );
  }
}
