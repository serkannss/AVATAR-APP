# ElevenLabs + XTTS Türkçe Akıllı Sesli Asistan

## Proje Özeti
Bu uygulama Flutter ile geliştirilmiştir. Kullanıcı, metinden sese (Text-to-Speech, TTS) ve sesten metne (Speech-to-Text, STT) çeviri yapabilir. ElevenLabs API'si ve dilerse yerel XTTS v2 (Coqui.ai) ile Türkçe klonlanmış kendi sesini kullanabilir.

---

## Özellikler
- ⭐ Modern, estetik, kullanıcı dostu UI
- ⭐ Türkçe metin -> doğal konuşma dönüşümü (TTS)
- ⭐ Otomatik sesten metne Türkçe transkripsiyon (STT)
- ⭐ ElevenLabs veya yerel sunucu ile klonlanmış ses desteği
- ⭐ Android, iOS, Web ve masaüstü desteği
- ⭐ Tüm API anahtarlarını .env ile gizli ve güvenli tutma


## Hızlı Kurulum ⏬

### 1. Flutter Ortamı
- [Flutter Kurulumu](https://flutter.dev/docs/get-started/install)

### 2. Repo Kurulumu
```bash
git clone https://github.com/serkannss/speech_to_text.git
cd speech_to_text/speech_to_text
```

### 3. Ortam Değişkenleri `.env`
- `.env.example` dosyasını `.env` olarak kopyala
- Gerçek API keylerini gir
deneme için anahtar al: [ElevenLabs](https://elevenlabs.io/) 
```env
ELEVENLABS_API_KEY=senin_api_keyin
elevenlabs_VOICE_ID=your_voice_id
ELEVENLABS_STT_MODEL=scribe_v1
# (opsiyonel) LOCAL_TTS_URL=http://localhost:8000/tts
```

### 4. Bağımlılıkları Yükle ve Başlat
```bash
flutter pub get
flutter run        # Mobil/desktop için
yada:
flutter run -d chrome  # Web için
```

---

## Ücretsiz XTTS Sunucusu (Kendi Sesinle TTS)

1. Gereksinimler: Python 3.10+, ffmpeg, pip
2. Kurulum:
```bash
pip install TTS fastapi uvicorn pydub numpy
```
3. `server.py` dosyasını projene ekle (detaylı örnek yukarıda veya issues kısmında mevcut)
4. Sunucuyu çalıştır
```bash
uvicorn server:app --host 0.0.0.0 --port 8000
```
5. `.env`'ye şu satırı ekle:
```
LOCAL_TTS_URL=http://localhost:8000/tts
```
---
## Güvenlik
- `.env` dosyası `.gitignore` ile korunuyor
- Diğer geliştiriciye örnek için `.env.example` var
- Kodun her yerinde dotenv ile anahtarlar güvenli çekiliyor

---

## Katkı & İletişim
Her türlü geri bildirim, öneri, PR ve feature request açıktır.

---


