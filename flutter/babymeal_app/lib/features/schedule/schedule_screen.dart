// lib/features/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'meal_provider.dart';
import 'meal_model.dart';
import 'meal_dialog.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  String get _selectedStr =>
      _selected.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('식단표')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMeal(context),
        child: const Icon(Icons.add),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (meals) {
          final byDate = <String, List<Meal>>{};
          for (final m in meals) {
            byDate.putIfAbsent(m.date, () => []).add(m);
          }
          final dayMeals = byDate[_selectedStr] ?? [];
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
                child: dayMeals.isEmpty
                    ? const Center(child: Text('등록된 식단이 없어요'))
                    : ListView.builder(
                        itemCount: dayMeals.length,
                        itemBuilder: (_, i) => _MealTile(
                          meal: dayMeals[i],
                          onRefresh: () => ref.invalidate(mealsProvider),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMeal(BuildContext context) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MealDialog(initialDate: _selectedStr),
    );
    if (data == null) return;
    try {
      await MealActions.add(data);
      ref.invalidate(mealsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }
}

class _MealTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onRefresh;
  const _MealTile({required this.meal, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(meal.statusColorInt),
          child: Text(meal.ingredients.isNotEmpty
              ? meal.ingredients.first.emoji
              : '🍽'),
        ),
        title: Text(meal.mealTimeKoStr),
        subtitle: Text(meal.ingredients.map((i) => i.name).join(', ')),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _onMenu(context, v),
          itemBuilder: (_) => [
            if (meal.status != 'confirmed')
              const PopupMenuItem(value: 'confirmed', child: Text('먹었어요')),
            if (meal.status != 'upcoming')
              const PopupMenuItem(value: 'upcoming', child: Text('안먹었어요')),
            if (meal.status != 'skipped')
              const PopupMenuItem(value: 'skipped', child: Text('건너뜀')),
            const PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      );

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('식단을 삭제하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await MealActions.delete(meal.id);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    } else {
      try {
        await MealActions.updateStatus(
          meal.id, action,
          consumedIds: action == 'confirmed'
              ? meal.ingredients.map((i) => i.ingredientId).toList()
              : null,
        );
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('상태 변경 실패: $e')));
        }
      }
    }
  }
}
