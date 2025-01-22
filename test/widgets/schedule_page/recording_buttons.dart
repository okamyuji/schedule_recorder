import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_recorder/widgets/schedule_page/recording_buttons.dart';

void main() {
  group('RecordingButtons', () {
    testWidgets('renders correctly when not recording or playing',
        (WidgetTester tester) async {
      // Arrange
      bool isRecording = false;
      bool isPlaying = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingButtons(
            isRecording: isRecording,
            isPlaying: isPlaying,
            onStartRecording: () {},
            onStopRecording: () {},
            onStartPlaying: () {},
            onStopPlaying: () {},
          ),
        ),
      );

      // Assert
      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.text('Play Recording'), findsOneWidget);
      expect(find.text('Stop Recording'), findsNothing);
      expect(find.text('Stop Playing'), findsNothing);
    });

    testWidgets(
        'calls onStartRecording when "Start Recording" button is tapped',
        (WidgetTester tester) async {
      // Arrange
      bool wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingButtons(
            isRecording: false,
            isPlaying: false,
            onStartRecording: () {
              wasCalled = true;
            },
            onStopRecording: () {},
            onStartPlaying: () {},
            onStopPlaying: () {},
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Start Recording'));
      await tester.pump();

      // Assert
      expect(wasCalled, true);
    });

    testWidgets('calls onStopRecording when "Stop Recording" button is tapped',
        (WidgetTester tester) async {
      // Arrange
      bool wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingButtons(
            isRecording: true,
            isPlaying: false,
            onStartRecording: () {},
            onStopRecording: () {
              wasCalled = true;
            },
            onStartPlaying: () {},
            onStopPlaying: () {},
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Stop Recording'));
      await tester.pump();

      // Assert
      expect(wasCalled, true);
    });

    testWidgets('calls onStartPlaying when "Play Recording" button is tapped',
        (WidgetTester tester) async {
      // Arrange
      bool wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingButtons(
            isRecording: false,
            isPlaying: false,
            onStartRecording: () {},
            onStopRecording: () {},
            onStartPlaying: () {
              wasCalled = true;
            },
            onStopPlaying: () {},
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Play Recording'));
      await tester.pump();

      // Assert
      expect(wasCalled, true);
    });

    testWidgets('calls onStopPlaying when "Stop Playing" button is tapped',
        (WidgetTester tester) async {
      // Arrange
      bool wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecordingButtons(
            isRecording: false,
            isPlaying: true,
            onStartRecording: () {},
            onStopRecording: () {},
            onStartPlaying: () {},
            onStopPlaying: () {
              wasCalled = true;
            },
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Stop Playing'));
      await tester.pump();

      // Assert
      expect(wasCalled, true);
    });
  });
}
