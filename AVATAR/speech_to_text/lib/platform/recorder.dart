import 'dart:typed_data';

import 'recorder_io.dart' if (dart.library.html) 'recorder_web.dart';

class RecordedAudio {
  final Uint8List bytes;
  final String mimeType; // e.g., audio/webm, audio/m4a
  RecordedAudio({required this.bytes, required this.mimeType});
}

abstract class AppRecorder {
  Future<void> start();
  Future<RecordedAudio?> stopAndGetBytes();
}

AppRecorder createRecorder() => RecorderImpl();


