import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:schedule_recorder/constants/strings.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  final documentsPath = appDir.path;
  final logger = Logger();

  runApp(ScheduleRecorderApp(
    documentsPath: documentsPath,
    logger: logger,
  ));
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
      home: SchedulePage(
        recorder: AudioRecorder(),
        player: AudioPlayer(),
        fileManagementService: FileManagementService(
          logger: logger,
          documentsPath: documentsPath,
        ),
        documentsPath: documentsPath,
        logger: logger,
      ),
    );
  }
}
