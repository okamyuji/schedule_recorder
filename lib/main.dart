import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_recorder/constants/schedule_page/strings.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'package:schedule_recorder/providers/schedule_page/recording_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  final documentsPath = appDir.path;
  final logger = Logger();

  runApp(
    ProviderScope(
      child: ScheduleRecorderApp(
        documentsPath: documentsPath,
        logger: logger,
      ),
    ),
  );
}

/// スケジュール録音アプリ
class ScheduleRecorderApp extends StatelessWidget {
  final String documentsPath;
  final Logger logger;

  const ScheduleRecorderApp({
    super.key,
    required this.documentsPath,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Consumer(
        builder: (context, ref, _) => SchedulePage(
          recorder: AudioRecorder(),
          player: AudioPlayer(),
          fileManagementService: FileManagementService(
            logger: logger,
            documentsPath: documentsPath,
          ),
          documentsPath: documentsPath,
          logger: logger,
          recordingStateNotifier: recordingStateNotifierProvider,
        ),
      ),
    );
  }
}
