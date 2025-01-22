import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:schedule_recorder/screens/schedule_page/schedule_page.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([FlutterSoundRecorder, FlutterSoundPlayer])
void main() {
  late MockFlutterSoundRecorder mockRecorder;
  late MockFlutterSoundPlayer mockPlayer;

  setUp(() {
    mockRecorder = MockFlutterSoundRecorder();
    mockPlayer = MockFlutterSoundPlayer();

    when(mockRecorder.openRecorder()).thenAnswer(
        (_) async => Future<FlutterSoundRecorder?>.value(mockRecorder));
    when(mockPlayer.openPlayer())
        .thenAnswer((_) async => Future<FlutterSoundPlayer?>.value(mockPlayer));
  });

  testWidgets('Schedule Recorder App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SchedulePage(
        recorder: mockRecorder,
        player: mockPlayer,
      ),
    ));

    await tester.pump(const Duration(milliseconds: 100));

    // Verify that recording buttons are present
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('Play Recording'), findsOneWidget);
  });
}
