import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/constants/strings.dart';

import 'screens/schedule_page/schedule_page.dart';

void main() {
  runApp(const ScheduleRecorderApp());
}

/// スケジュール録音アプリ
class ScheduleRecorderApp extends StatelessWidget {
  const ScheduleRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SchedulePage(
        recorder: AudioRecorder(),
        player: AudioPlayer(),
      ),
    );
  }
}
