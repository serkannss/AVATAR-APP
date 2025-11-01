import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'recorder.dart';

class RecorderImpl implements AppRecorder {
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  bool _stopping = false;

  @override
  Future<void> start() async {
    final stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    // Prefer opus/ogg for ElevenLabs STT compatibility
    final options = jsify({'mimeType': 'audio/ogg;codecs=opus'});
    try {
      _recorder = html.MediaRecorder(stream, options);
    } catch (_) {
      _recorder = html.MediaRecorder(stream); // fallback
    }
    _chunks.clear();
    _stopping = false;
    _recorder!.addEventListener('dataavailable', (html.Event e) {
      final dynamic ev = e;
      if (ev is html.BlobEvent && ev.data != null) {
        _chunks.add(ev.data!);
        // If stop was requested and we received a final chunk, some browsers
        // may not fire 'stop' immediately; guard-complete after small delay.
        if (_stopping) {
          // no-op; stop handler will consume
        }
      }
    });
    // Start with timeslice so dataavailable fires periodically
    // This helps ensure a final chunk exists even on short recordings
    _recorder!.start(200);
  }

  @override
  Future<RecordedAudio?> stopAndGetBytes() async {
    if (_recorder == null) return null;
    final c = Completer<RecordedAudio?>();
    bool completed = false;
    _stopping = true;
    _recorder!.addEventListener('stop', (html.Event _) async {
      if (completed) return;
      completed = true;
      final blob = html.Blob(_chunks, 'audio/ogg;codecs=opus');
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      reader.onLoadEnd.listen((_) {
        final dynamic res = reader.result;
        Uint8List bytes;
        if (res is ByteBuffer) {
          bytes = Uint8List.view(res);
        } else if (res is Uint8List) {
          bytes = res;
        } else {
          bytes = Uint8List(0);
        }
        c.complete(RecordedAudio(bytes: bytes, mimeType: 'audio/ogg'));
      });
    });
    // Flush pending data chunk then stop
    try { _recorder!.requestData(); } catch (_) {}
    // Fallback timeout in case 'stop' event isn't delivered promptly
    Future.delayed(const Duration(milliseconds: 400), () {
      if (completed) return;
      if (_chunks.isNotEmpty) {
        completed = true;
        final blob = html.Blob(_chunks, 'audio/ogg;codecs=opus');
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
      reader.onLoadEnd.listen((_) {
        final dynamic res = reader.result;
        Uint8List bytes;
        if (res is ByteBuffer) {
          bytes = Uint8List.view(res);
        } else if (res is Uint8List) {
          bytes = res;
        } else {
          bytes = Uint8List(0);
        }
        c.complete(RecordedAudio(bytes: bytes, mimeType: 'audio/ogg'));
      });
      }
    });
    _recorder!.stop();
    return c.future;
  }

  // Minimal jsify to pass options map
  dynamic jsify(Map<String, Object> map) {
    final obj = html.document.createElement('div');
    // dummy object; MediaRecorder accepts a JS object, but in Dart we can
    // pass a map directly in most cases. This helper just returns the map.
    return map;
  }
}


