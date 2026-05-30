// lib/features/inventory/ingredient_dialog.dart
import 'package:flutter/material.dart';
import 'ingredient_model.dart';

class IngredientDialog extends StatefulWidget {
  final Ingredient? existing;
  const IngredientDialog({super.key, this.existing});

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _unitType = 'weight';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emojiCtrl.text = e.emoji;
      _totalCtrl.text = e.totalCubes.toString();
      _weightCtrl.text = e.weightPerCube?.toString() ?? '';
      _dateCtrl.text = e.createdAt;
      _unitType = e.unitType;
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    }
  }

  Map<String, dynamic> toData() => {
        'name': _nameCtrl.text.trim(),
        'emoji': _emojiCtrl.text.trim(),
        'color': '#4BA3E3',
        'created_at': _dateCtrl.text.trim(),
        'total_cubes': int.tryParse(_totalCtrl.text) ?? 0,
        'weight_per_cube': _unitType == 'weight'
            ? int.tryParse(_weightCtrl.text)
            : null,
        'unit_type': _unitType,
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? '재료 추가' : '재료 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_emojiCtrl, '이모지', hint: '🥕'),
              _field(_nameCtrl, '이름'),
              _field(_dateCtrl, '제작일 (YYYY-MM-DD)'),
              _field(_totalCtrl, '총 큐브 수', keyboard: TextInputType.number),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weight', label: Text('무게')),
                  ButtonSegment(value: 'quantity', label: Text('개수')),
                ],
                selected: {_unitType},
                onSelectionChanged: (s) =>
                    setState(() => _unitType = s.first),
              ),
              if (_unitType == 'weight')
                _field(_weightCtrl, '큐브당 무게 (g)', keyboard: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, toData()),
              child: const Text('저장')),
        ],
      );

  Widget _field(TextEditingController c, String label,
      {String? hint, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emojiCtrl, _totalCtrl, _weightCtrl, _dateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }
}
