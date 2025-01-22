import 'package:flutter/material.dart';

class RecordingButtons extends StatelessWidget {
  final bool isRecording;
  final bool isPlaying;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onStartPlaying;
  final VoidCallback onStopPlaying;

  const RecordingButtons({
    super.key,
    required this.isRecording,
    required this.isPlaying,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onStartPlaying,
    required this.onStopPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: isRecording ? onStopRecording : onStartRecording,
          child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isPlaying ? onStopPlaying : onStartPlaying,
          child: Text(isPlaying ? 'Stop Playing' : 'Play Recording'),
        ),
      ],
    );
  }
}
