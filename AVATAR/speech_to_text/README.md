# 🎤 Avatar Speech Learning App

Flutter tabanlı interaktif konuşma öğrenme uygulaması. ElevenLabs ve Deepgram API'leri ile gerçek zamanlı ses kaydı, transkripsiyon ve kelime bazlı doğruluk analizi yaparak İngilizce telaffuz geliştirmenize yardımcı olur.

![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8.1+-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web%20%7C%20Desktop-lightgrey)

## ✨ Özellikler

- 🎙️ **Gerçek Zamanlı Ses Kaydı** - Mikrofon ile ses kaydı yapın
- 🔊 **Text-to-Speech** - Cümleleri dinleyerek doğru telaffuzu öğrenin
- 📝 **Speech-to-Text** - Konuşmanızı otomatik olarak metne dönüştürün
- 📊 **Kelime Bazlı Skor Analizi** - Her kelime için doğruluk skoru ve karşılaştırmalı analiz
- 🎬 **Avatar Video Entegrasyonu** - Cümlelere özel avatar videoları
- 📱 **Cross-Platform** - iOS, Android, Web, Windows, macOS, Linux desteği
- 🎯 **Görsel Skor Tablosu** - Renkli ve profesyonel kelime skorlama arayüzü

## 📋 Gereksinimler

- Flutter SDK 3.8.1 veya üzeri
- Dart SDK 3.8.1 veya üzeri
- ElevenLabs API Key
- Deepgram API Key

## 🚀 Hızlı Başlangıç

### 1. Projeyi Klonlayın

```bash
git clone <your-repo-url>
cd AVATAR/speech_to_text
```

### 2. Bağımlılıkları Yükleyin

```bash
flutter pub get
```

### 3. API Key'lerini Alın

#### ElevenLabs API Key
1. [ElevenLabs](https://elevenlabs.io/) hesabı oluşturun
2. [API Keys](https://elevenlabs.io/app/settings/api-keys) sayfasına gidin
3. Yeni bir API key oluşturun veya mevcut key'inizi kopyalayın
4. [Voices](https://elevenlabs.io/app/voices) sayfasından Voice ID'nizi bulun

#### Deepgram API Key
1. [Deepgram](https://console.deepgram.com/signup) hesabı oluşturun
2. Dashboard'dan API key'inizi oluşturun

### 4. Environment Dosyasını Oluşturun

Proje kök dizininde `.env` dosyası oluşturun:

**Windows (PowerShell):**
```powershell
New-Item .env
```

**Linux/Mac:**
```bash
touch .env
```

### 5. API Key'lerinizi Ekleyin

`.env` dosyasını açıp aşağıdaki formatı kullanarak kendi key'lerinizi ekleyin:

```env
ELEVENLABS_API_KEY=sk_your_api_key_here
ELEVENLABS_VOICE_ID=your_voice_id_here
ELEVENLABS_STT_MODEL=scribe_v1
DEEPGRAM_API_KEY=your_deepgram_api_key_here
```

> 💡 `.env.example` dosyasını referans olarak kullanabilirsiniz.

### 6. Uygulamayı Çalıştırın

```bash
flutter run
```

## 📖 Kullanım

1. **Cümle Seçimi**: Ekranda görünen İngilizce cümlelerden birini seçin
2. **Orijinali Dinle**: "Orjinali Dinle" butonuyla doğru telaffuzu dinleyin
3. **Ses Kaydet**: "Ses Kaydet" butonuna basarak kaydınızı başlatın ve cümleyi söyleyin
4. **Skorları İncele**: Kayıt sonrası kelime bazlı doğruluk skorlarınızı görün
5. **Geliştirin**: Skorları takip ederek telaffuzunuzu geliştirin

### Skor Tablosu Renkleri

- 🟢 **Yeşil (✓)**: Kelime doğru söylenmiş (Skor: 0.60+)
- 🟡 **Sarı (⚠)**: Kelime doğru ama düşük güven skoru (Skor: 0.60 altı)
- 🔴 **Kırmızı (✗)**: Kelime yanlış söylenmiş veya söylenmemiş

## 🏗️ Proje Yapısı

```
speech_to_text/
├── lib/
│   ├── main.dart                 # Uygulama giriş noktası
│   ├── ui/
│   │   └── home_page.dart        # Ana sayfa ve UI
│   ├── services/
│   │   ├── elevenlabs_service.dart    # ElevenLabs API entegrasyonu
│   │   └── deepgram_service.dart      # Deepgram API entegrasyonu
│   └── platform/
│       ├── recorder.dart          # Platform-agnostic recorder
│       ├── recorder_io.dart       # Native platform kayıt
│       └── recorder_web.dart     # Web platform kayıt
├── assets/                       # Avatar video dosyaları
├── .env                          # ⚠️ API key'ler (GitHub'a YÜKLENMEMELİ)
├── .env.example                  # Örnek environment dosyası
└── pubspec.yaml                  # Proje konfigürasyonu
```

## 🔧 Teknolojiler

| Teknoloji | Kullanım |
|-----------|----------|
| **Flutter** | Cross-platform UI framework |
| **ElevenLabs API** | Text-to-Speech ve Speech-to-Text |
| **Deepgram API** | Konuşma analizi ve kelime skorlama |
| **flutter_dotenv** | Environment variables yönetimi |
| **record** | Ses kaydı (platform-native) |
| **audioplayers** | Ses oynatma |
| **video_player** | Avatar video oynatma |

## 🔐 Güvenlik

⚠️ **ÖNEMLİ**: 
- `.env` dosyası **ASLA** GitHub'a commit edilmemeli
- `.gitignore` dosyası `.env`'yi zaten hariç tutuyor
- API key'lerinizi kimseyle paylaşmayın
- `.env.example` dosyası sadece şablon içindir (gerçek key'ler yok)

## 🐛 Sorun Giderme

### `.env` dosyası bulunamıyor

**Sorun**: `Warning: .env file not found or could not be loaded`

**Çözüm**:
- `.env` dosyasının `speech_to_text/` klasörü içinde olduğundan emin olun
- Dosya adının tam olarak `.env` olduğunu kontrol edin (`.env.txt` değil!)
- Dosya formatının doğru olduğunu kontrol edin (boş satır veya özel karakter yok)

### API Key Hatası

**Sorun**: `DEEPGRAM_API_KEY not found in .env file` veya API çağrıları başarısız

**Çözüm**:
- `.env` dosyasında tüm key'lerin tanımlı olduğunu kontrol edin
- Key'lerin başında/sonunda gereksiz boşluk olmadığını kontrol edin
- ElevenLabs ve Deepgram hesaplarınızın aktif olduğunu doğrulayın
- API key'lerinizin süresi dolmamış olduğunu kontrol edin

### Ses Kaydı Çalışmıyor

**Sorun**: Mikrofon izni verilmiş ama kayıt başlamıyor

**Çözüm**:
- Uygulama ayarlarından mikrofon izninin verildiğini kontrol edin
- Tarayıcı için HTTPS bağlantısı kullandığınızdan emin olun (Web)
- iOS/Android için Info.plist ve AndroidManifest.xml izinlerini kontrol edin

### Deepgram Skorları Görünmüyor

**Sorun**: Ses kaydı yapılıyor ama skor tablosu boş

**Çözüm**:
- İnternet bağlantınızı kontrol edin
- Deepgram API key'inizin doğru olduğunu kontrol edin
- Konsol loglarında hata mesajı olup olmadığını kontrol edin

## 📱 Platform Desteği

| Platform | Destekleniyor | Notlar |
|----------|--------------|--------|
| **iOS** | ✅ | Mikrofon izni gereklidir |
| **Android** | ✅ | Android 6.0+ gereklidir |
| **Web** | ✅ | HTTPS gerekir, tarayıcı izni gereklidir |
| **Windows** | ✅ | Test edilmiştir |
| **macOS** | ✅ | Test edilmiştir |
| **Linux** | ✅ | Test edilmiştir |

## 🎯 Gelecek Özellikler

- [ ] Çoklu dil desteği
- [ ] İlerleme takibi ve istatistikler
- [ ] Özel cümle ekleme
- [ ] Sesli geri bildirim
- [ ] Leaderboard sistemi

## 📄 Lisans

Bu proje özel kullanım içindir.


⭐ **Projeyi beğendiyseniz yıldız vermeyi unutmayın!**
