import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart'; // 追加
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

final logger = Logger();

class SchedulePage extends StatefulWidget {
  final FlutterSoundRecorder recorder;
  final FlutterSoundPlayer player;

  const SchedulePage({
    super.key,
    required this.recorder,
    required this.player,
  });

  @override
  SchedulePageState createState() => SchedulePageState();
}

class SchedulePageState extends State<SchedulePage> {
  bool isRecording = false;
  bool isPlaying = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();

    // AudioServiceのリスナーを設定
    AudioService.setupNativeListeners(
      onInterrupted: _handleRecordingInterrupted,
      onResumed: _handleRecordingResumed,
    );
  }

  Future<void> _initializeRecorder() async {
    await widget.recorder.openRecorder();
    await widget.player.openPlayer();

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('マイクの権限が必要です');
    }

    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/recording.aac';
  }

  Future<void> _startRecording() async {
    if (!isRecording && _recordingPath != null) {
      try {
        await widget.recorder.startRecorder(
          toFile: _recordingPath,
          codec: Codec.aacADTS,
          sampleRate: 44100,
          bitRate: 128000,
        );
        setState(() {
          isRecording = true;
        });
      } catch (e) {
        logger.e('録音開始エラー: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (isRecording) {
      try {
        await widget.recorder.stopRecorder();
        setState(() {
          isRecording = false;
        });
      } catch (e) {
        logger.e('録音停止エラー: $e');
      }
    }
  }

  Future<void> _startPlaying() async {
    if (!isPlaying && _recordingPath != null) {
      try {
        await widget.player.startPlayer(
          fromURI: _recordingPath,
          codec: Codec.aacADTS,
          whenFinished: () {
            setState(() {
              isPlaying = false;
            });
          },
        );
        setState(() {
          isPlaying = true;
        });
        await widget.player.setVolume(5.0);
      } catch (e) {
        logger.e('再生開始エラー: $e');
      }
    }
  }

  Future<void> _stopPlaying() async {
    if (isPlaying) {
      try {
        await widget.player.stopPlayer();
        setState(() {
          isPlaying = false;
        });
      } catch (e) {
        logger.e('再生停止エラー: $e');
      }
    }
  }

  // 中断時のハンドラ
  void _handleRecordingInterrupted() {
    if (isRecording) {
      _stopRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('録音が中断されました')),
      );
    }
  }

  // 再開時のハンドラ
  void _handleRecordingResumed() {
    // 録音を再開
    _startRecording();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('録音が再開されました')),
    );
  }

  @override
  void dispose() {
    widget.recorder.closeRecorder();
    widget.player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRecording)
              const Text('録音中...', style: TextStyle(color: Colors.red)),
            if (isPlaying)
              const Text('再生中...', style: TextStyle(color: Colors.green)),
            const SizedBox(height: 20),
            // 録音＆再生ボタン群
            RecordingButtons(
              isRecording: isRecording,
              isPlaying: isPlaying,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
              onStartPlaying: _startPlaying,
              onStopPlaying: _stopPlaying,
            ),
          ],
        ),
      ),
    );
  }
}
