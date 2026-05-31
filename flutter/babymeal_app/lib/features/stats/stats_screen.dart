// lib/features/stats/stats_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../inventory/ingredient_model.dart';
import '../inventory/ingredient_provider.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);
const _red = Color(0xFFe05c5c);
const _redLight = Color(0xFFffe5e7);
const _barBlue = Color(0xFF4BA3E3);
const _lowThreshold = 3;

Color _hexToColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return _barBlue;
  }
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingredientsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('통계'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: async.maybeWhen(
              data: (items) => _ExportButton(items: items),
              orElse: () => const SizedBox(),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📊', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('재료를 먼저 추가해주세요',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }
          final totalCubes = items.fold(0, (s, i) => s + i.currentCubes);
          final lowCount = items.where((i) => i.isLowStock).length;
          final sorted = [...items]
            ..sort((a, b) => b.currentCubes.compareTo(a.currentCubes));
          final double maxCubes =
              sorted.isEmpty ? 1.0 : sorted.first.currentCubes.toDouble();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── 요약 카드 3개 ────────────────────────────────────────────
              Row(
                children: [
                  _StatCard(
                    value: '${items.length}가지',
                    label: '재료 종류',
                    valueColor: _green,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: '${totalCubes}개',
                    label: '총 큐브 수',
                    valueColor: _green,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: '${lowCount}가지',
                    label: '재고 부족 (${_lowThreshold}개 이하)',
                    valueColor: lowCount > 0 ? _red : _green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── 가로 막대 그래프 ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('재료별 재고 현황',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _green)),
                    const SizedBox(height: 20),
                    ...sorted.map((ing) =>
                        _HBar(ing: ing, maxCubes: maxCubes)),
                    const SizedBox(height: 8),
                    _XAxisLabels(maxCubes: maxCubes),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── 재고 부족 섹션 ───────────────────────────────────────────
              if (lowCount > 0) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10)
                    ],
                    border: Border.all(color: _red.withOpacity(0.2)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _redLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('⚠️ 재고 부족',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _red)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items
                            .where((i) => i.isLowStock)
                            .map((i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _redLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${i.emoji} ${i.name}  ${i.currentCubes}개',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: _red,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── 요약 카드 ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatCard(
      {required this.value, required this.label, required this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ],
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: valueColor)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ── 가로 막대 ─────────────────────────────────────────────────────────────────
class _HBar extends StatelessWidget {
  final Ingredient ing;
  final double maxCubes;
  const _HBar({required this.ing, required this.maxCubes});

  @override
  Widget build(BuildContext context) {
    final isLow = ing.isLowStock;
    final ratio = maxCubes <= 0 ? 0.0 : ing.currentCubes / maxCubes;
    final label = ing.weightPerCube != null && ing.weightPerCube! > 0
        ? '${ing.emoji} ${ing.name}  ${ing.weightPerCube}g'
        : '${ing.emoji} ${ing.name}';
    final barColor = isLow ? _red : _hexToColor(ing.color);
    final barBg = isLow ? _redLight : barColor.withOpacity(0.15);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isLow ? _red : const Color(0xFF444444)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('${ing.currentCubes}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLow ? _red : _green),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── X축 레이블 ────────────────────────────────────────────────────────────────
class _XAxisLabels extends StatelessWidget {
  final double maxCubes;
  const _XAxisLabels({required this.maxCubes});

  @override
  Widget build(BuildContext context) {
    final max = maxCubes.ceil();
    final step = max <= 10 ? 1 : (max / 5).ceil();
    final labels = <int>[];
    for (var i = 0; i <= max; i += step) {
      labels.add(i);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 118),
      child: Row(
        children: labels
            .map((v) => Expanded(
                  child: Text('$v',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                      textAlign: v == 0 ? TextAlign.left : TextAlign.center),
                ))
            .toList(),
      ),
    );
  }
}

// ── 엑셀 내보내기 버튼 ────────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final List<Ingredient> items;
  const _ExportButton({required this.items});

  Future<void> _export(BuildContext context) async {
    try {
      final buf = StringBuffer();
      buf.writeln('재료명,이모지,현재큐브,총큐브,단위타입,큐브당무게(g),재고상태');
      for (final i in items) {
        final status = i.isLowStock ? '부족' : '정상';
        final weight = i.weightPerCube?.toString() ?? '';
        buf.writeln(
            '"${i.name}","${i.emoji}",${i.currentCubes},${i.totalCubes},"${i.unitType}","$weight","$status"');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/babymeal_stats.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: 'babymeal_stats.csv')],
        subject: '치밀한 이유식 재고 현황',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _export(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _lightMint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _mint.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, color: _green, size: 16),
              SizedBox(width: 4),
              Text('엑셀 내보내기',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _green)),
            ],
          ),
        ),
      );
}
