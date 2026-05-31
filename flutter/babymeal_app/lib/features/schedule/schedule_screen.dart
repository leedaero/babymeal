// lib/features/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'meal_provider.dart';
import 'meal_model.dart';
import 'meal_dialog.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  String get _selectedStr => _selected.toIso8601String().substring(0, 10);

  String get _selectedLabel {
    final now = DateTime.now();
    if (isSameDay(_selected, now)) return '오늘 식단';
    return '${_selected.month}월 ${_selected.day}일 식단';
  }

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(mealsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('식단 관리'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.add, color: _green, size: 18),
                onPressed: () => _addMeal(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (meals) {
          final byDate = <String, List<Meal>>{};
          for (final m in meals) {
            byDate.putIfAbsent(m.date, () => []).add(m);
          }
          final dayMeals = byDate[_selectedStr] ?? [];

          return Column(
            children: [
              Container(
                color: Colors.white,
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  onDaySelected: (sel, foc) =>
                      setState(() { _selected = sel; _focused = foc; }),
                  eventLoader: (d) =>
                      byDate[d.toIso8601String().substring(0, 10)] ?? [],
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _green,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: _mint),
                    rightChevronIcon: Icon(Icons.chevron_right, color: _mint),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: _mint.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    todayTextStyle: const TextStyle(color: _green, fontWeight: FontWeight.w800),
                    selectedDecoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    markerDecoration: const BoxDecoration(color: _mint, shape: BoxShape.circle),
                    markerSize: 5,
                    weekendTextStyle: const TextStyle(color: Color(0xFFe63946)),
                    defaultTextStyle: const TextStyle(color: Color(0xFF333333)),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFe63946)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedLabel,
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _mint,
                          )),
                      const SizedBox(height: 10),
                      Expanded(
                        child: dayMeals.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🍽', style: TextStyle(fontSize: 40)),
                                    const SizedBox(height: 8),
                                    const Text('등록된 식단이 없어요',
                                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () => _addMeal(context),
                                      icon: const Icon(Icons.add, color: _mint),
                                      label: const Text('식단 추가', style: TextStyle(color: _mint)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: dayMeals.length,
                                itemBuilder: (_, i) => _MealCard(
                                  meal: dayMeals[i],
                                  onRefresh: () => ref.invalidate(mealsProvider),
                                ),
                              ),
                      ),
                    ],
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
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onRefresh;
  const _MealCard({required this.meal, required this.onRefresh});

  Color get _timeColor {
    switch (meal.mealTimeKoStr) {
      case '아침': return _mint;
      case '점심': return const Color(0xFF457b9d);
      case '저녁': return const Color(0xFFe07c24);
      default: return Colors.grey;
    }
  }

  Color get _timeBg {
    switch (meal.mealTimeKoStr) {
      case '아침': return _lightMint;
      case '점심': return const Color(0xFFe8f4fd);
      case '저녁': return const Color(0xFFfff3e0);
      default: return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _timeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(meal.mealTimeKoStr,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _timeColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.ingredients.isNotEmpty
                          ? meal.ingredients.map((i) => i.name).join(', ')
                          : '재료 없음',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green),
                    ),
                    if (meal.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meal.ingredients.map((i) => i.emoji).join(' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusBadge(status: meal.status),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) => _onMenu(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('수정 ✏️')),
                  if (meal.status != 'confirmed')
                    const PopupMenuItem(value: 'confirmed', child: Text('먹었어요 ✅')),
                  if (meal.status != 'upcoming')
                    const PopupMenuItem(value: 'upcoming', child: Text('예정으로 변경')),
                  if (meal.status != 'skipped')
                    const PopupMenuItem(value: 'skipped', child: Text('건너뜀')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제', style: TextStyle(color: Color(0xFFe63946))),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'edit') {
      final data = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MealDialog(initialDate: meal.date, existing: meal),
      );
      if (data == null) return;
      try {
        await MealActions.update(meal.id, data);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        }
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Text('식단을 삭제하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe63946)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.white)),
            ),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'confirmed' => ('먹었어요', const Color(0xFFd8f3dc), _green),
      'skipped' => ('건너뜀', const Color(0xFFffe5e7), const Color(0xFFe63946)),
      _ => ('예정', const Color(0xFFF0F0F0), Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
