// lib/features/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inventory/inventory_screen.dart';
import '../schedule/schedule_screen.dart';
import '../allergy/allergy_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';

final tabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = [
    InventoryScreen(),
    ScheduleScreen(),
    AllergyScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(tabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: idx, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) =>
            ref.read(tabIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.kitchen), label: '재고'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '식단'),
          NavigationDestination(icon: Icon(Icons.science), label: '알러지'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '통계'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
