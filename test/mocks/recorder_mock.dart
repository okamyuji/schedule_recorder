import 'package:mockito/annotations.dart';
import 'package:record/record.dart';

@GenerateMocks([], customMocks: [
  MockSpec<AudioRecorder>(
    as: #MockAudioRecorder,
  ),
])
void main() {}
