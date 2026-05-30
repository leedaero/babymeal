// lib/features/allergy/allergy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'allergy_provider.dart';
import 'allergy_model.dart';

class AllergyScreen extends ConsumerStatefulWidget {
  const AllergyScreen({super.key});
  @override
  ConsumerState<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends ConsumerState<AllergyScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  String get _selectedStr => _selected.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allergyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('알러지 테스트')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (tests) {
          final byDate = <String, List<AllergyTest>>{};
          for (final t in tests) {
            byDate.putIfAbsent(t.testDate, () => []).add(t);
          }
          final dayTests = byDate[_selectedStr] ?? [];
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (sel, foc) =>
                    setState(() { _selected = sel; _focused = foc; }),
                eventLoader: (d) =>
                    byDate[d.toIso8601String().substring(0, 10)] ?? [],
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(formatButtonVisible: false),
              ),
              const Divider(),
              Expanded(
                child: dayTests.isEmpty
                    ? const Center(child: Text('이날 테스트가 없어요'))
                    : ListView.builder(
                        itemCount: dayTests.length,
                        itemBuilder: (_, i) => _AllergyTile(
                          test: dayTests[i],
                          onRefresh: () => ref.invalidate(allergyProvider),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final data = await _showDialog(context, null);
    if (data == null) return;
    try {
      await AllergyActions.add(data);
      ref.invalidate(allergyProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }

  Future<Map<String, dynamic>?> _showDialog(
      BuildContext context, AllergyTest? existing) {
    final emojiCtrl =
        TextEditingController(text: existing?.emoji ?? '🧪');
    final nameCtrl =
        TextEditingController(text: existing?.ingredientName ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? '테스트 추가' : '테스트 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emojiCtrl,
                decoration: const InputDecoration(labelText: '이모지', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: '재료명', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: memoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '반응 메모', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'test_date': _selectedStr,
              'emoji': emojiCtrl.text.trim(),
              'ingredient_name': nameCtrl.text.trim(),
              'memo': memoCtrl.text.trim(),
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _AllergyTile extends StatelessWidget {
  final AllergyTest test;
  final VoidCallback onRefresh;
  const _AllergyTile({required this.test, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Text(test.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(test.ingredientName),
        subtitle: test.memo.isNotEmpty ? Text(test.memo) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              try {
                await AllergyActions.delete(test.id);
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                }
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      );
}
