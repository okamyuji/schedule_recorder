import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const MethodChannel _channel =
    MethodChannel('com.example.schedule_recorder/audio');

void main() {
  runApp(ScheduleRecorderApp());
}

class ScheduleRecorderApp extends StatelessWidget {
  const ScheduleRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule Recorder',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SchedulePage(),
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  SchedulePageState createState() => SchedulePageState();
}

class SchedulePageState extends State<SchedulePage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializePlayer();
    _setupNativeListeners(
      onInterrupted: _stopRecording,
      onResumed: _startRecording,
    );
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();

      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission not granted');
      }

      final directory = await getApplicationDocumentsDirectory();
      _filePath = '${directory.path}/recorded_audio.aac';
    } catch (e) {
      print('Recorder initialization failed: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.openPlayer();
    } catch (e) {
      print('Player initialization failed: $e');
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecording && _filePath != null) {
      try {
        await _recorder.startRecorder(toFile: _filePath);
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('Error starting recording: $e');
      }
    }
  }

  // ネイティブ通知リスナーのセットアップ
  static void _setupNativeListeners(
      {required Function onInterrupted, required Function onResumed}) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'RecordingInterrupted':
          onInterrupted(); // 録音停止処理
          break;
        case 'RecordingResumed':
          onResumed(); // 録音再開処理
          break;
        default:
          throw UnsupportedError('Unknown method: ${call.method}');
      }
    });
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      try {
        await _recorder.stopRecorder();
        setState(() {
          _isRecording = false;
        });
      } catch (e) {
        print('Error stopping recording: $e');
      }
    }
  }

  Future<void> _playRecording() async {
    if (!_isPlaying && _filePath != null) {
      try {
        await _player.startPlayer(
          fromURI: _filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            setState(() {
              _isPlaying = false;
            });
          },
        );
        setState(() {
          _isPlaying = true;
        });
      } catch (e) {
        print('Error playing recording: $e');
      }
    }
  }

  Future<void> _stopPlaying() async {
    if (_isPlaying) {
      try {
        await _player.stopPlayer();
        setState(() {
          _isPlaying = false;
        });
      } catch (e) {
        print('Error stopping playback: $e');
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Schedule Recorder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording)
              Text('Recording...',
                  style: TextStyle(fontSize: 20, color: Colors.red)),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            SizedBox(height: 20),
            if (_isPlaying)
              Text('Playing...',
                  style: TextStyle(fontSize: 20, color: Colors.green)),
            ElevatedButton(
              onPressed: _isPlaying ? _stopPlaying : _playRecording,
              child: Text(_isPlaying ? 'Stop Playing' : 'Play Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
