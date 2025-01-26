// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';

// Project imports:
import 'package:schedule_recorder/main.dart';
import 'package:schedule_recorder/services/schedule_page/file_management_service.dart';
import 'main_test.mocks.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/test/path';
}

@GenerateMocks([
  AudioPlayer,
  AudioRecorder,
  FileManagementService,
  Logger,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('main', () {
    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
    });

    test('アプリケーションが正常に初期化されること', () {
      // WidgetsFlutterBindingが初期化されていることを確認
      expect(WidgetsBinding.instance, isNotNull);
    });
  });

  group('ScheduleRecorderApp Tests', () {
    late MockLogger mockLogger;
    late String documentsPath;

    setUp(() async {
      mockLogger = MockLogger();
      documentsPath = '/test/path';
    });

    testWidgets('アプリが正常に起動すること', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: ScheduleRecorderApp(
            documentsPath: documentsPath,
            logger: mockLogger,
          ),
        ),
      );

      // アプリのタイトルが表示されていることを確認
      expect(find.text('Schedule Recorder'), findsOneWidget);
    });

    testWidgets('必要なウィジェットが表示されること', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: ScheduleRecorderApp(
            documentsPath: documentsPath,
            logger: mockLogger,
          ),
        ),
      );

      // AppBarが表示されていることを確認
      expect(find.byType(AppBar), findsOneWidget);

      // SafeAreaが表示されていることを確認
      expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
    });
  });
}
