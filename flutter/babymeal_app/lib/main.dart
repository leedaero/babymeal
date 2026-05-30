// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
