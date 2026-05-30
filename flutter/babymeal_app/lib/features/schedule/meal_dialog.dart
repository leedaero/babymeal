// lib/features/schedule/meal_dialog.dart
import 'package:flutter/material.dart';
import '../inventory/ingredient_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MealDialog extends ConsumerStatefulWidget {
  final String initialDate;
  const MealDialog({super.key, required this.initialDate});
  @override
  ConsumerState<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends ConsumerState<MealDialog> {
  String _mealTime = 'morning';
  final _noteCtrl = TextEditingController();
  final Map<int, int> _selected = {}; // ingredientId → grams

  static const _times = [
    ('morning', '아침'), ('morning_snack', '오전간식'),
    ('lunch', '점심'), ('snack', '오후간식'),
    ('dinner', '저녁'),
  ];

  Map<String, dynamic> toData() => {
        'date': widget.initialDate,
        'meal_time': _mealTime,
        'note': _noteCtrl.text.trim(),
        'ingredients': _selected.entries
            .map((e) => {'ingredient_id': e.key, 'grams': e.value})
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    return AlertDialog(
      title: Text('식단 추가 (${widget.initialDate})'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _mealTime,
              items: _times
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _mealTime = v!),
              decoration: const InputDecoration(
                  labelText: '끼니', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ingredientsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('재료 로드 실패: $e'),
              data: (items) => Wrap(
                spacing: 8,
                children: items
                    .map((ing) => FilterChip(
                          label: Text('${ing.emoji}${ing.name}'),
                          selected: _selected.containsKey(ing.id),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selected[ing.id] = 1;
                            } else {
                              _selected.remove(ing.id);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: '메모', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            final data = toData();
            Navigator.pop(context, data);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }
}
