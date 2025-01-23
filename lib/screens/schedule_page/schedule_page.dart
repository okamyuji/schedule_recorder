import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/services/schedule_page/audio_service.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

final logger = Logger();

class SchedulePage extends StatefulWidget {
  final AudioRecorder recorder;
  final AudioPlayer player;

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
  bool isPaused = false;
  String? _recordingPath;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }).catchError((e) {
      logger.e('Recorder initialization error: $e');
    });
  }

  Future<void> _initializeRecorder() async {
    try {
      logger.i('Initializing recorder...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('マイクの権限が必要です');
      }
      logger.i('Microphone permission granted');

      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/recording.m4a';
      logger.i('Recording path set to: $_recordingPath');

      logger.i('Recorder initialization completed successfully');
    } catch (e) {
      logger.e('Recorder initialization error: $e');
      rethrow;
    }
  }

  Future<void> _startRecording() async {
    if (!_isInitialized) {
      logger.w('Recorder is not initialized yet');
      return;
    }

    if (!isRecording && _recordingPath != null) {
      try {
        logger.i('Starting recording...');

        // AudioServiceのリスナーを設定
        AudioService.setupNativeListeners(
          onInterrupted: () {
            logger.i('Audio interruption detected');
            if (isRecording && !isPaused) {
              _handleRecordingInterrupted();
            }
          },
          onResumed: () {
            logger.i('Audio resumption detected');
            if (isPaused) {
              _handleRecordingResumed();
            }
          },
        );

        // 録音開始前に状態をリセット
        if (mounted) {
          setState(() {
            isPaused = false;
          });
        }

        await widget.recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );

        // 録音開始後に状態を更新
        if (mounted) {
          setState(() {
            isRecording = true;
          });
          logger.i('Recording started successfully');
        }
      } catch (e) {
        logger.e('録音開始エラー: $e');
        if (mounted) {
          setState(() {
            isRecording = false;
            isPaused = false;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音の開始に失敗しました')),
          );
        }
      }
    }
  }

  Future<void> _stopRecording() async {
    if (isRecording) {
      try {
        logger.i('Stopping recording...');
        await widget.recorder.stop();
        setState(() {
          isRecording = false;
          isPaused = false;
        });
        logger.i('Recording stopped');
      } catch (e) {
        logger.e('録音停止エラー: $e');
      }
    }
  }

  Future<void> _startPlaying() async {
    if (!isPlaying && _recordingPath != null) {
      try {
        logger.i('Starting playback...');
        setState(() {
          isRecording = false;
          isPaused = false;
        });

        await widget.player.setVolume(1.0);
        await widget.player.setFilePath(_recordingPath!);

        if (mounted) {
          setState(() {
            isPlaying = true;
          });
        }

        widget.player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            logger.i('Playback finished');
            if (mounted) {
              setState(() {
                isPlaying = false;
              });
            }
          }
        });

        await widget.player.play();
        logger.i('Playback started');
      } catch (e) {
        logger.e('再生開始エラー: $e');
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
      }
    }
  }

  Future<void> _stopPlaying() async {
    if (isPlaying) {
      try {
        logger.i('Stopping playback...');
        await widget.player.stop();
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
        logger.i('Playback stopped');
      } catch (e) {
        logger.e('再生停止エラー: $e');
      }
    }
  }

  Future<void> _handleRecordingInterrupted() async {
    logger.i(
        'Recording interrupted handler called. isRecording: $isRecording, isPaused: $isPaused');
    if (isRecording && !isPaused) {
      try {
        logger.i('Recording interrupted...');
        await widget.recorder.pause();
        if (mounted) {
          setState(() {
            isPaused = true;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音を一時停止しました')),
          );
        }
      } catch (e) {
        logger.e('録音の一時停止に失敗しました: $e');
      }
    }
  }

  Future<void> _handleRecordingResumed() async {
    if (isPaused) {
      try {
        logger.i('Resuming recording...');
        await widget.recorder.resume();
        if (mounted) {
          setState(() {
            isPaused = false;
          });
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音を再開しました')),
          );
        }
      } catch (e) {
        logger.e('録音の再開に失敗しました: $e');
        if (mounted) {
          final context = this.context;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('録音の再開に失敗しました')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    if (isRecording) {
      widget.recorder.stop();
    }
    if (isPlaying) {
      widget.player.stop();
    }
    widget.recorder.dispose();
    widget.player.dispose();
    logger.i('Recorder and Player disposed');
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
            if (!_isInitialized)
              const CircularProgressIndicator()
            else ...[
              RecordingButtons(
                isRecording: isRecording,
                isPlaying: isPlaying,
                isPaused: isPaused,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onStartPlaying: _startPlaying,
                onStopPlaying: _stopPlaying,
                onPauseRecording: _handleRecordingInterrupted,
                onResumeRecording: _handleRecordingResumed,
              ),
              const SizedBox(height: 20),
              if (isRecording && !isPaused)
                const Text('録音中...', style: TextStyle(fontSize: 16))
              else if (isRecording && isPaused)
                const Text('録音一時停止中...', style: TextStyle(fontSize: 16))
              else if (isPlaying)
                const Text('再生中...', style: TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
