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
          colorSchemeSeed: const Color(0xFF4BA3E3),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
}
