import 'dart:io';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../services/elevenlabs_service.dart';
import '../platform/recorder.dart';
import '../services/deepgram_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> currentIndex = ValueNotifier(0);
  final _textController = TextEditingController();
  final _record = AudioRecorder();
  late final AppRecorder _appRecorder;
  final _player = AudioPlayer();
  final _service = ElevenLabsService();
  VideoPlayerController? _videoCtrl;
  String? _avatarVideoUrl; // Buraya URL eklenecek
  String? _avatarAssetPath; // Asset video için

  bool _isRecording = false;
  String? _recordPath;
  String _transcript = '';
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Uint8List? _lastRecordingBytes; // Son kayıt sesi burada tutulacak

  late final DeepgramService deepgram;
  List<DeepgramWordScore> _deepgramScores = [];

  Future<void> _playSentenceVideoAssetOnce(String assetPath) async {
    try {
      final previousController = _videoCtrl;
      final controller = VideoPlayerController.asset(assetPath);
      await controller.initialize();
      controller.setLooping(false);

      bool hasReturnedToDefault = false;

      controller.addListener(() async {
        if (!mounted || hasReturnedToDefault) return;
        final v = controller.value;
        if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
          hasReturnedToDefault = true;
          await _setAvatarVideoAsset('assets/avatar.mp4');
          await controller.dispose();
        }
      });

      setState(() {
        _videoCtrl = controller;
        _avatarAssetPath = assetPath;
        _avatarVideoUrl = null;
      });

      await controller.play();
      await previousController?.dispose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video oynatma hatası: $e')),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    _videoCtrl?.dispose();
    _timer?.cancel();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    _appRecorder = createRecorder();
    // Deepgram service'i .env'den API key ile initialize et
    final deepgramApiKey = dotenv.env['DEEPGRAM_API_KEY'] ?? '';
    if (deepgramApiKey.isEmpty) {
      throw Exception('DEEPGRAM_API_KEY not found in .env file');
    }
    deepgram = DeepgramService(deepgramApiKey);
    // Varsayılan asset videoyu yükle
    _setAvatarVideoAsset('assets/avatar.mp4');
  }

  Future<void> _setAvatarVideoUrl(String url) async {
    try {
      _avatarVideoUrl = url;
      _avatarAssetPath = null; // network seçildiğinde asset temizle
      final old = _videoCtrl;
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(true);
      await _videoCtrl!.play();
      if (mounted) setState(() {});
      await old?.dispose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video yüklenemedi: $e')));
    }
  }

  Future<void> _setAvatarVideoAsset(String assetPath) async {
    try {
      _avatarAssetPath = assetPath;
      _avatarVideoUrl = null; // asset seçildiğinde network temizle
      final old = _videoCtrl;
      _videoCtrl = VideoPlayerController.asset(assetPath);
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(true);
      await _videoCtrl!.play();
      if (mounted) setState(() {});
      await old?.dispose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Asset video yüklenemedi: $e')));
    }
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _ensurePermissions() async {
    if (kIsWeb) {
      // Web'de storage izni yok; mikrofon izni tarayici prompt'u ile gelir
      return;
    }
    final mic = await Permission.microphone.request();
    if (mic.isDenied) throw Exception('Mikrofon izni gerekli');
  }

  Future<void> _toggleRecord() async {
    try {
      await _ensurePermissions();
      if (!_isRecording) {
        setState(() {
          _recordPath = null;
          _lastRecordingBytes = null;
        });
        await _appRecorder.start();
        _elapsed = Duration.zero;
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _elapsed += const Duration(seconds: 1));
        });
        setState(() => _isRecording = true);
      } else {
        final rec = await _appRecorder.stopAndGetBytes();
        setState(() => _isRecording = false);
        _timer?.cancel();
        if (rec != null) {
          setState(() {
            _busy = true;
            _lastRecordingBytes = rec.bytes;
          });
          try {
            if (!kIsWeb) {
              final dir = await getTemporaryDirectory();
              final path = '${dir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';
              final f = File(path);
              await f.writeAsBytes(rec.bytes);
              // Dosya kaydı gerçekten oldu mu kontrol edelim:
              if (!await f.exists()) {
                throw Exception("Kayıt başarısız: Dosya bulunamadı.");
              }
              setState(() => _recordPath = path);
            } else {
              setState(() => _recordPath = null); // Web'de dosya yok, bytes üzerinden oynat
            }
            final text = await _service.speechBytesToText(bytes: rec.bytes, mimeType: rec.mimeType);
            if (!mounted) return;
            setState(() => _transcript = text);

            // ----- DEEPGRAM PUAN ANALİZİ ENTEGRASYON -----
            await _analyzeWithDeepgram(audioBytes: rec.bytes, mimeType: rec.mimeType);

          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transkripsiyon ya da kayıt hatası: $e')));
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayit hatasi: $e')));
    }
  }

  Future<void> _doTranscribe() async {
    if (_recordPath == null) return;
    setState(() => _busy = true);
    try {
      final text = await _service.speechToText(audioFile: File(_recordPath!));
      setState(() => _transcript = text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transkripsiyon hatasi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doTts(String? text) async {
    final toSay = text?.trim() ?? '';
    if (toSay.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await _service.textToSpeech(text: toSay);
      if (kIsWeb) {
        final dataUri = 'data:audio/mpeg;base64,' + base64Encode(bytes);
        await _player.play(UrlSource(dataUri));
      } else {
        await _player.play(BytesSource(bytes));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TTS hatasi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyzeWithDeepgram({Uint8List? audioBytes, String mimeType = 'audio/mp4'}) async {
    if (audioBytes == null) return;
    setState(() => _busy = true);
    try {
      final result = await deepgram.analyzeAudio(bytes: audioBytes, mimeType: mimeType);
      setState(() {
        _deepgramScores = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deepgram analiz hatası: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxAvatarSize = 420.0, minAvatarSize = 200.0;
    final avatarSize = (screenWidth * 0.7).clamp(minAvatarSize, maxAvatarSize);
    final cardWidth = (screenWidth * 0.6).clamp(150.0, 230.0);
    final cardFontSize = (screenWidth < 340) ? 13.0 : ((screenWidth < 390) ? 15.0 : 17.0);
    final cardSentences = [
      'He drives his car to work',
      'The weather is very nice today',
      'We are going to see a movie.',
      'You can speak English very well',
      'He is reading a new book',
      'I like to drink coffee',
      'They play football every Sunday',
      'She works in a big office',
      'She is a very good student',
      'My favorite color is blue',
    ];
    final cardColors = [Colors.white, Colors.grey[200], Colors.grey[300]];
    final cardScrollController = ScrollController();
    //final ValueNotifier<int> currentIndex = ValueNotifier(0); // BU SATIRI SİL

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Avatar App', style: TextStyle(
            color: Colors.black,
            fontSize: (screenWidth < 360) ? 17 : 21,
        )),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // --- AVATAR WINDOW ---
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dışarıda ve üstte başlık
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Builder(
                          builder: (context) {
                            final gradient = const LinearGradient(
                              colors: [Color(0xFF000000), Color(0xFF7A7A7A), Color(0xFFFFFFFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            );
                            final paint = Paint()
                              ..shader = gradient.createShader(
                                Rect.fromLTWH(0, 0, avatarSize, 40),
                              );
                            return Text(
                              'RİONALDO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (screenWidth < 360) ? 20 : 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                foreground: paint,
                                shadows: [
                                  Shadow(color: Colors.black.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        margin: EdgeInsets.only(bottom: screenWidth < 350 ? 22 : 38),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(avatarSize * 0.18),
                          border: Border.all(color: Colors.grey[500]!, width: 3.1),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: (_videoCtrl != null && _videoCtrl!.value.isInitialized)
                          ? FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: _videoCtrl!.value.size.width,
                                height: _videoCtrl!.value.size.height,
                                child: VideoPlayer(_videoCtrl!),
                              ),
                            )
                          : Center(
                              child: Text(
                                'Avatar',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: avatarSize * 0.15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                  // --- SCROLLABLE CARD ---
                  ValueListenableBuilder<int>(
                    valueListenable: currentIndex,
                    builder: (context, selected, __) {
                      final isAtStart = selected <= 0;
                      final isAtEnd = selected >= cardSentences.length - 1;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Sol ok
                          IconButton(
                            icon: Icon(
                              Icons.arrow_left,
                              size: 34,
                              color: isAtStart ? Colors.grey[300] : Colors.grey[800],
                            ),
                            onPressed: () {
                              if (!isAtStart) {
                                currentIndex.value = selected - 1;
                              }
                            },
                          ),
                          Expanded(
                            child: SizedBox(
                              height: (screenWidth < 390) ? 68 : 84,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: cardWidth,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey[800]!, // Çerçeve artık koyu gri
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey[600]!.withOpacity(0.16),
                                        blurRadius: 10,
                                        spreadRadius: 1.5,
                                        offset: const Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      cardSentences[selected],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: cardFontSize,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Sağ ok
                          IconButton(
                            icon: Icon(
                              Icons.arrow_right,
                              size: 34,
                              color: isAtEnd ? Colors.grey[300] : Colors.grey[800],
                            ),
                            onPressed: () {
                              if (!isAtEnd) {
                                currentIndex.value = selected + 1;
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: screenWidth < 340 ? 14 : 20),
                  // --- SPEECH/TT BOX ---
                  ValueListenableBuilder<int>(
                    valueListenable: currentIndex,
                    builder: (context, selectedIdx, __) {
                      final shownText = cardSentences[selectedIdx];
                      return Card(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  shownText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 11),
                              // --- 2x2 BUTTON GRID ---
                              SizedBox(
                                child: GridView.count(
                                  shrinkWrap: true,
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 2.9,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[800],
                                          foregroundColor: Colors.white),
                                      onPressed: _busy ? null : () async {
                                        await _toggleRecord();
                                      },
                                      icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 18),
                                      label: Text(_isRecording ? 'Durdur' : 'Ses Kaydet', style: const TextStyle(fontSize: 13)),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[700],
                                          foregroundColor: Colors.white),
                                      onPressed: _busy ? null : () async {
                                        await _doTts(shownText);
                                      },
                                      icon: const Icon(Icons.volume_up, size: 18),
                                      label: const Text('Orjinali Dinle', style: TextStyle(fontSize: 13)),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[400],
                                          foregroundColor: Colors.black),
                                      onPressed: () async {
                                        // Seçili metne göre ilgili video asset'i oynat
                                        final Map<String, String> textToAsset = {
                                          'He drives his car to work': 'assets/metin1.mp4',
                                          'The weather is very nice today': 'assets/metin2.mp4',
                                          'We are going to see a movie.': 'assets/metin3.mp4',
                                          'You can speak English very well': 'assets/metin4.mp4',
                                          'He is reading a new book': 'assets/metin5.mp4',
                                          'I like to drink coffee': 'assets/metin6.mp4',
                                          'They play football every Sunday': 'assets/metin7.mp4',
                                          'She works in a big office': 'assets/metin8.mp4',
                                          'She is a very good student': 'assets/metin9.mp4',
                                          'My favorite color is blue': 'assets/metin10.mp4',
                                        };
                                        final asset = textToAsset[shownText];
                                        if (asset != null) {
                                          await _playSentenceVideoAssetOnce(asset);
                                        } else {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Bu metin için video bulunamadı.')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.account_circle, size: 17),
                                      label: const Text('Avatar', style: TextStyle(fontSize: 13)),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: (kIsWeb
                                          ? _lastRecordingBytes == null
                                          : _recordPath == null) ? Colors.grey[200] : Colors.blue[600],
                                        foregroundColor: (kIsWeb
                                          ? _lastRecordingBytes == null
                                          : _recordPath == null) ? Colors.black38 : Colors.white,
                                      ),
                                      onPressed: ((kIsWeb ? _lastRecordingBytes == null : _recordPath == null) || _busy) ? null : () async {
                                        if (kIsWeb) {
                                          if (_lastRecordingBytes != null) {
                                            // Web'de bytes'ı geçici olarak çal
                                            final base64audio = base64Encode(_lastRecordingBytes!);
                                            final dataUri = 'data:audio/mpeg;base64,$base64audio';
                                            await _player.play(UrlSource(dataUri));
                                          }
                                        } else {
                                          if (_recordPath != null) {
                                            await _player.play(DeviceFileSource(_recordPath!));
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.play_arrow_rounded, size: 21),
                                      label: const Text('Kaydı Dinle', style: TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 13),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                padding: const EdgeInsets.all(18),
                                height: (screenWidth < 370) ? 90 : 116,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  _transcript.isEmpty ? 'Kayıt sonucu burada görünecek.' : _transcript,
                                  style: TextStyle(fontSize: (screenWidth < 350) ? 13 : 16, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenWidth < 340 ? 14 : 20),
                  // Skor Tablosu widget
                  buildScoreTable(cardSentences[currentIndex.value].trim()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildScoreTable(String shownText) {
    if (_deepgramScores.isEmpty) return Container(height: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Kart cümlesindeki kelimeleri temizle ve ayır
    final shownWords = shownText.toLowerCase()
        .replaceAll(RegExp(r"[.,!?;:]"), "")
        .trim()
        .split(RegExp(r"\s+"))
        .where((w) => w.isNotEmpty)
        .toList();
    
    // Deepgram'dan gelen kelimeleri temizle ve normalize et
    final deepgramWords = _deepgramScores.map((w) => 
        w.word.toLowerCase().replaceAll(RegExp(r"[.,!?;:]"), "").trim()
    ).where((w) => w.isNotEmpty).toList();
    
    // Kart cümlesindeki her kelime için Deepgram'da eşleşen kelimeyi bul
    List<CompareRow> rows = [];
    Set<int> usedDeepgramIndices = {}; // Her Deepgram kelimesini sadece bir kez kullan
    
    for (final correctWord in shownWords) {
      String matchedSpoken = '';
      double matchedConfidence = 0.0;
      int matchedIndex = -1;
      
      // Deepgram kelimeleri arasında tam eşleşme ara (kullanılmamış olanlar arasında)
      for (int i = 0; i < deepgramWords.length; i++) {
        if (usedDeepgramIndices.contains(i)) continue;
        
        if (deepgramWords[i] == correctWord) {
          matchedSpoken = deepgramWords[i];
          matchedConfidence = _deepgramScores[i].confidence;
          matchedIndex = i;
          usedDeepgramIndices.add(i);
          break;
        }
      }
      
      // Tam eşleşme bulunamadıysa, kısmi eşleşme veya boş geç
      int result;
      if (matchedIndex >= 0) {
        // Kelime bulundu: confidence'e göre değerlendir
        if (matchedConfidence >= 0.75) {
          result = 1; // Yeşil tik - tam doğru
        } else if (matchedConfidence >= 0.60) {
          result = 1; // Yeşil tik - doğru ama confidence orta
        } else {
          result = 0; // Sarı uyarı - kelime doğru ama confidence çok düşük
        }
        rows.add(CompareRow(correct: correctWord, said: matchedSpoken, confidence: matchedConfidence, result: result));
      } else {
        // Kelime söylenmemiş veya eşleşmemiş
        rows.add(CompareRow(correct: correctWord, said: '', confidence: 0.0, result: -1));
      }
    }

    // Doğru sayısı: Kelime eşleşenleri say (correct == said ve boş değil)
    int correctCount = rows.where((r) => r.correct == r.said && r.correct.isNotEmpty).length;
    double percent = rows.isEmpty ? 0 : (correctCount / rows.length * 100);

    Color scoreColor(double pct) {
      if (pct >= 90) return Colors.green[600]!;
      if (pct >= 75) return Colors.amber[700]!;
      return Colors.redAccent;
    }

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      color: isDark ? const Color(0xFF18181c) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, size: 27, color: Colors.deepPurple),
                const SizedBox(width: 10),
                const Text('Kelime Doğruluk Skoru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor(percent).withOpacity(0.13),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(percent > 89 ? Icons.emoji_events : (percent > 75 ? Icons.thumb_up : Icons.error_outline), color: scoreColor(percent), size: 20),
                    const SizedBox(width: 5),
                    Text("${percent.toStringAsFixed(0)}%", style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor(percent))),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Row(
                children: const [
                  Expanded(child: Text('Doğru', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Söylediğin', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 18),
                  Text('Skor', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 5),
            ...rows.asMap().entries.map((entry) {
              final r = entry.value;
              Color color;
              IconData? icon;
              if (r.result == 1) {
                color = Colors.green[600]!;
                icon = Icons.check_circle_outline;
              } else if (r.result == 0) {
                color = Colors.amber[700]!;
                icon = Icons.warning_amber_outlined;
              } else {
                color = Colors.redAccent;
                icon = Icons.cancel_outlined;
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? Colors.white12 : Colors.grey[100],
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  minLeadingWidth: 19,
                  leading: Icon(icon, size: 20, color: color),
                  title: Row(
                    children: [
                      Expanded(child: Text(r.correct, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                      Expanded(child: Text(r.said, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[800]))),
                    ],
                  ),
                  trailing: r.confidence > 0
                    ? Text(r.confidence.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: color))
                    : const SizedBox(width: 1),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class CompareRow {
  final String correct;
  final String said;
  final double confidence;
  /// result: 1=tam doğru, 0=kısmen uyarı, -1=eksik/yanlış
  final int result;
  CompareRow({required this.correct, required this.said, required this.confidence, required this.result});
}



