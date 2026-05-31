// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/push/fcm_service.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.init();
  runApp(const ProviderScope(child: BabyMealApp()));
}

class BabyMealApp extends StatelessWidget {
  const BabyMealApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '치밀한 이유식',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2d6a4f),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7FAF8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1b4332),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1b4332),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2d6a4f),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFd8f3dc),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2d6a4f));
              }
              return const TextStyle(fontSize: 11, color: Colors.grey);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF2d6a4f));
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
        ),
        home: const SplashScreen(),
      );
}
