// lib/features/shell/main_shell.dart
import 'package:flutter/material.dart';
import '../inventory/inventory_screen.dart';
import '../schedule/schedule_screen.dart';
import '../allergy/allergy_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  static const _tabs = [
    InventoryScreen(),
    ScheduleScreen(),
    AllergyScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _idx, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
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
