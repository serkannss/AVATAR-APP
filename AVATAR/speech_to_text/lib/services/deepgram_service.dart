import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DeepgramWordScore {
  final String word;
  final double confidence;
  final int start;
  final int end;

  DeepgramWordScore({required this.word, required this.confidence, required this.start, required this.end});
}

class DeepgramService {
  final String apiKey;
  DeepgramService(this.apiKey);
  Future<List<DeepgramWordScore>> analyzeAudio({required Uint8List bytes, required String mimeType}) async {
    final url = Uri.parse('https://api.deepgram.com/v1/listen?punctuate=true&utterances=true');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Token $apiKey',
        'Content-Type': mimeType
      },
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception('Deepgram error: \\${response.statusCode} \\${response.body}');
    }
    final res = jsonDecode(response.body);
    final List<DeepgramWordScore> wordScores = [];
    for (final utt in res['results']['utterances'] ?? []) {
      for (final word in utt['words'] ?? []) {
        wordScores.add(
          DeepgramWordScore(
              word: word['word'] ?? '',
              confidence: (word['confidence'] ?? 0.0)+0.0,
              start: (word['start'] * 1000).toInt(),
              end: (word['end'] * 1000).toInt(),
          )
        );
      }
    }
    return wordScores;
  }
}
