import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/store_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/store_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each init step is wrapped so a failure in one cannot prevent the
  // app from launching. A "grey screen on launch" was traced to one of
  // these throwing on certain devices.
  try {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp]);
  } catch (e) {
    debugPrint('Orientation lock failed: $e');
  }
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (e) {
    debugPrint('UI mode failed: $e');
  }
  try {
    await StoreService.instance.init();
  } catch (e) {
    debugPrint('Store init failed: $e');
  }
  try {
    await AdService.instance.initialize();
  } catch (e) {
    debugPrint('Ad init failed: $e');
  }
  // Fire-and-forget — audio init is non-essential and must NEVER block
  // launch. The first BGM play() will gracefully no-op if init failed.
  AudioService.instance.init();

  runApp(const DeliveryDashApp());
}

class DeliveryDashApp extends StatelessWidget {
  const DeliveryDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFFFFD600),
          surface: Color(0xFF1A1A2E),
          error: Color(0xFFFF1744),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
        '/gameover': (context) => const GameOverScreen(),
        '/store': (context) => const StoreScreen(),
      },
    );
  }
}
