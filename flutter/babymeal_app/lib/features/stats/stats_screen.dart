// lib/features/stats/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../inventory/ingredient_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('재료가 없어요'));
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: (items.length * 60.0).clamp(300, 1200),
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: items
                      .map((i) => i.totalCubes.toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barGroups: items.asMap().entries.map((e) {
                    final ing = e.value;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: ing.currentCubes.toDouble(),
                          color: ing.isLowStock
                              ? Colors.orange
                              : const Color(0xFF4BA3E3),
                          width: 28,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= items.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(items[i].emoji,
                                style: const TextStyle(fontSize: 16)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
