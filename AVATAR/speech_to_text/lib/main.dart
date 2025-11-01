import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env dosyasını yükle (assets klasöründe olmalı)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Web'de veya .env yoksa hata verme, runtime'da kontrol edilecek
    if (kDebugMode) {
      print("Warning: .env file not found or could not be loaded: $e");
    }
  }
  
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElevenLabs Demo',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          background: Color(0xFFF6F6F6),
          onSurface: Colors.black87,
          secondary: Colors.grey,
          onSecondary: Colors.black,
          primaryContainer: Colors.grey,
          onPrimaryContainer: Colors.black,
          surfaceVariant: Color(0xFFD9D9D9),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Color(0xFF181818),
          background: Colors.black,
          onSurface: Colors.white70,
          secondary: Colors.grey,
          onSecondary: Colors.white,
          primaryContainer: Colors.black,
          onPrimaryContainer: Colors.white,
          surfaceVariant: Color(0xFF444444),
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// Removed template counter page; using HomePage instead
