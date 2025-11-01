import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'recorder.dart';

class RecorderImpl implements AppRecorder {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/input_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
      path: _path!,
    );
  }

  @override
  Future<RecordedAudio?> stopAndGetBytes() async {
    final p = await _rec.stop();
    final path = p ?? _path;
    if (path == null) return null;
    final bytes = await File(path).readAsBytes();
    return RecordedAudio(bytes: bytes, mimeType: 'audio/mp4');
  }
}


