// lib/features/inventory/ingredient_dialog.dart
import 'package:flutter/material.dart';
import 'ingredient_model.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

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

  bool get _isEdit => widget.existing != null;

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
        'weight_per_cube': _unitType == 'weight' ? int.tryParse(_weightCtrl.text) : null,
        'unit_type': _unitType,
      };

  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                          color: _green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(_isEdit ? '재료 수정' : '재료 추가',
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _green,
                        )),
                  ],
                ),
                const SizedBox(height: 24),

                // 이모지 + 이름 가로 배치
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: _buildField(
                        controller: _emojiCtrl,
                        label: '이모지',
                        hint: '🥕',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        controller: _nameCtrl,
                        label: '재료 이름',
                        hint: '당근',
                        icon: Icons.label_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 제작일
                _buildField(
                  controller: _dateCtrl,
                  label: '제작일',
                  hint: 'YYYY-MM-DD',
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 14),

                // 총 큐브 수
                _buildField(
                  controller: _totalCtrl,
                  label: '총 큐브 수',
                  hint: '0',
                  icon: Icons.grid_view_rounded,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 14),

                // 단위 선택
                const Text('단위 유형',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _mint)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _unitChip('weight', '⚖️ 무게'),
                    const SizedBox(width: 10),
                    _unitChip('quantity', '🔢 개수'),
                  ],
                ),
                const SizedBox(height: 14),

                // 큐브당 무게
                if (_unitType == 'weight') ...[
                  _buildField(
                    controller: _weightCtrl,
                    label: '큐브당 무게 (g)',
                    hint: '30',
                    icon: Icons.monitor_weight_outlined,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                ],

                // 버튼
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _lightMint, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('취소', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_mint, _green]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: _mint.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, toData()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(_isEdit ? '수정 완료' : '추가하기',
                              style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _unitChip(String value, String label) {
    final selected = _unitType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _unitType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _green : _lightMint.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _green : _lightMint),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _green,
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        textAlign: textAlign,
        style: style,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: _mint, size: 18) : null,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _lightMint),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _lightMint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _mint, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
