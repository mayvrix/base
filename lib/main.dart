import 'package:base/core/theme_colors.dart';
import 'package:base/firebase_options.dart';
import 'package:base/tools/bot_nav_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio/just_audio.dart';

// 🔊 Global singleton AudioPlayer (dispose when app closes)
final AudioPlayer globalPlayer = AudioPlayer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);


  // ✅ Transparent status bar with white text/icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
      
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://ecewuepokrwagkfhlwjd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjZXd1ZXBva3J3YWdrZmhsd2pkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYwMTAyODYsImV4cCI6MjA3MTU4NjI4Nn0.F0fS2RIaBntjnysO2GZv69Xdxc1G_7x0nReNbw-hrb8',
  );

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.yourapp.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,

  );

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// 👇 Lifecycle observer added here
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalPlayer.dispose(); // ✅ release audio properly
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      globalPlayer.stop();
      globalPlayer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        extensions: [AppColors(palette)],
        scaffoldBackgroundColor: palette.bg,
      ),
      home: const SplashScreen(),
    );
  }
}
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);

    Future.delayed(const Duration(milliseconds: 2500), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.light();
    return Scaffold(
      backgroundColor: palette.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "base" text
            Text(
              "base",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: palette.text,
                fontFamily: "monospace",letterSpacing: -1
              ),
            ),
            const SizedBox(height: 4),

            // loading bar (matches text width)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    double textWidth = 72; // approx width of "base"
                    double progress =
                        Curves.easeInOut.transform(_controller.value);

                    return Container(
                      width: textWidth,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.text, // background bar
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.newPrimary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
