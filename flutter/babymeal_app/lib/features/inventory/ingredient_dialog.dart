// lib/features/inventory/ingredient_dialog.dart
import 'package:flutter/material.dart';
import 'ingredient_model.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

// Cube color palette
const _cubeColors = [
  Color(0xFFCC2200),
  Color(0xFFE86500),
  Color(0xFFF5C400),
  Color(0xFF2E8B3A),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFF00796B),
  Color(0xFFE57373),
  Color(0xFFFFFFFF),
];

String _colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

Color _hexToColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return _cubeColors[4];
  }
}

// ── 이모지 데이터 ──────────────────────────────────────────
const _emojiList = [
  // 채소
  {'e': '🥕', 'ko': '당근', 'en': 'carrot'},
  {'e': '🥦', 'ko': '브로콜리', 'en': 'broccoli'},
  {'e': '🌽', 'ko': '옥수수', 'en': 'corn'},
  {'e': '🍠', 'ko': '고구마', 'en': 'sweet potato'},
  {'e': '🥬', 'ko': '청경채', 'en': 'bok choy'},
  {'e': '🧅', 'ko': '양파', 'en': 'onion'},
  {'e': '🧄', 'ko': '마늘', 'en': 'garlic'},
  {'e': '🥒', 'ko': '오이', 'en': 'cucumber'},
  {'e': '🥑', 'ko': '아보카도', 'en': 'avocado'},
  {'e': '🫑', 'ko': '파프리카', 'en': 'bell pepper'},
  {'e': '🍆', 'ko': '가지', 'en': 'eggplant'},
  {'e': '🥔', 'ko': '감자', 'en': 'potato'},
  {'e': '🍅', 'ko': '토마토', 'en': 'tomato'},
  {'e': '🫛', 'ko': '완두콩', 'en': 'peas'},
  {'e': '🌶', 'ko': '고추', 'en': 'pepper'},
  {'e': '🥗', 'ko': '채소', 'en': 'salad'},
  // 과일
  {'e': '🍎', 'ko': '사과', 'en': 'apple'},
  {'e': '🍏', 'ko': '청사과', 'en': 'green apple'},
  {'e': '🍌', 'ko': '바나나', 'en': 'banana'},
  {'e': '🍊', 'ko': '귤', 'en': 'orange'},
  {'e': '🍋', 'ko': '레몬', 'en': 'lemon'},
  {'e': '🍓', 'ko': '딸기', 'en': 'strawberry'},
  {'e': '🍇', 'ko': '포도', 'en': 'grape'},
  {'e': '🥝', 'ko': '키위', 'en': 'kiwi'},
  {'e': '🍑', 'ko': '복숭아', 'en': 'peach'},
  {'e': '🫐', 'ko': '블루베리', 'en': 'blueberry'},
  {'e': '🍒', 'ko': '체리', 'en': 'cherry'},
  {'e': '🥭', 'ko': '망고', 'en': 'mango'},
  {'e': '🍍', 'ko': '파인애플', 'en': 'pineapple'},
  {'e': '🍐', 'ko': '배', 'en': 'pear'},
  {'e': '🍈', 'ko': '멜론', 'en': 'melon'},
  // 단백질
  {'e': '🥩', 'ko': '소고기', 'en': 'beef'},
  {'e': '🍗', 'ko': '닭고기', 'en': 'chicken'},
  {'e': '🍖', 'ko': '돼지고기', 'en': 'pork'},
  {'e': '🐟', 'ko': '생선', 'en': 'fish'},
  {'e': '🦐', 'ko': '새우', 'en': 'shrimp'},
  {'e': '🥚', 'ko': '달걀', 'en': 'egg'},
  {'e': '🍳', 'ko': '계란후라이', 'en': 'fried egg'},
  {'e': '🫘', 'ko': '콩', 'en': 'beans'},
  {'e': '🥜', 'ko': '땅콩', 'en': 'peanut'},
  // 곡물
  {'e': '🌾', 'ko': '쌀', 'en': 'rice'},
  {'e': '🍚', 'ko': '밥', 'en': 'cooked rice'},
  {'e': '🍞', 'ko': '식빵', 'en': 'bread'},
  {'e': '🫓', 'ko': '빵', 'en': 'flatbread'},
  {'e': '🌰', 'ko': '밤', 'en': 'chestnut'},
  {'e': '🥣', 'ko': '오트밀', 'en': 'oatmeal'},
  // 유제품
  {'e': '🥛', 'ko': '우유', 'en': 'milk'},
  {'e': '🧀', 'ko': '치즈', 'en': 'cheese'},
  {'e': '🧈', 'ko': '버터', 'en': 'butter'},
  {'e': '🫙', 'ko': '요거트', 'en': 'yogurt'},
  // 기타
  {'e': '🍯', 'ko': '꿀', 'en': 'honey'},
  {'e': '🫚', 'ko': '기름', 'en': 'oil'},
  {'e': '🧂', 'ko': '소금', 'en': 'salt'},
  {'e': '🍵', 'ko': '차', 'en': 'tea'},
];

// ── 이모지 검색 다이얼로그 ──────────────────────────────────
class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog();
  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Map<String, String>> get _results {
    if (_query.isEmpty) return List<Map<String, String>>.from(_emojiList);
    final q = _query.toLowerCase();
    return _emojiList.where((item) {
      return (item['ko'] ?? '').contains(q) ||
          (item['en'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.emoji_emotions_outlined, color: _green, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('이모지 검색',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _green)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '당근, chicken...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: _mint, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF7FAF8),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightMint)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightMint)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _mint, width: 2)),
              ),
            ),
            const SizedBox(height: 10),
            Text(results.isEmpty ? '검색 결과 없음' : '${results.length}개',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('😅 찾는 재료가 없어요', style: TextStyle(color: Colors.grey))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                      itemBuilder: (_, i) {
                        final item = results[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, item['e']),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text(item['e']!, style: const TextStyle(fontSize: 22))),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['ko']!,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
                                    Text(item['en']!,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 재료 추가/수정 시트 ──────────────────────────────────────
class IngredientSheet extends StatefulWidget {
  final Ingredient? existing;
  const IngredientSheet({super.key, this.existing});

  @override
  State<IngredientSheet> createState() => _IngredientSheetState();
}

class _IngredientSheetState extends State<IngredientSheet> {
  final _nameCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _unitType = 'weight';
  String _emoji = '';
  Color _selectedColor = _cubeColors[4];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emoji = e.emoji;
      _totalCtrl.text = e.totalCubes.toString();
      _weightCtrl.text = e.weightPerCube?.toString() ?? '';
      _dateCtrl.text = e.createdAt;
      _unitType = e.unitType;
      final parsed = _hexToColor(e.color);
      _selectedColor = _cubeColors.contains(parsed) ? parsed : _cubeColors[4];
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _totalCtrl, _weightCtrl, _dateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => const _EmojiPickerDialog(),
    );
    if (picked != null) setState(() => _emoji = picked);
  }

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return '재료 이름을 입력해주세요';
    if (int.tryParse(_totalCtrl.text) == null) return '총 큐브 수를 숫자로 입력해주세요';
    if (_unitType == 'weight') {
      final w = int.tryParse(_weightCtrl.text.trim());
      if (w == null || w <= 0) return '무게 단위 선택 시 큐브당 무게(g)를 입력해주세요';
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFe63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'emoji': _emoji,
      'color': _colorToHex(_selectedColor),
      'created_at': _dateCtrl.text.trim(),
      'total_cubes': int.tryParse(_totalCtrl.text) ?? 0,
      'weight_per_cube': _unitType == 'weight' ? int.tryParse(_weightCtrl.text) : null,
      'unit_type': _unitType,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 그라디언트 헤더 ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_mint, _green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                        color: Colors.white, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEdit ? '재료 수정' : '재료 추가',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── 폼 ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이모지 + 이름
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickEmoji,
                        child: Container(
                          width: 72, height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _lightMint),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _emoji.isEmpty
                                  ? const Icon(Icons.add_reaction_outlined, color: _mint, size: 22)
                                  : Text(_emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 2),
                              Text(
                                _emoji.isEmpty ? '이모지' : '변경',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
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

                  _buildField(
                    controller: _dateCtrl,
                    label: '제작일',
                    hint: 'YYYY-MM-DD',
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    controller: _totalCtrl,
                    label: '총 큐브 수',
                    hint: '0',
                    icon: Icons.grid_view_rounded,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // 단위 유형
                  const Text('단위 유형',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _mint)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _unitChip('weight', '⚖️ 무게'),
                    const SizedBox(width: 10),
                    _unitChip('quantity', '🔢 개수'),
                  ]),
                  const SizedBox(height: 14),

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

                  // 큐브 색상
                  const Text('큐브 색상',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _mint)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _cubeColors.map((c) {
                      final isSelected = _selectedColor.value == c.value;
                      final isWhite = c.value == const Color(0xFFFFFFFF).value;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? _green
                                  : (isWhite ? Colors.grey.shade300 : Colors.transparent),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 6)]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 16,
                                  color: isWhite ? _green : Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

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
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              _isEdit ? '수정 완료' : '추가하기',
                              style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: _mint, size: 18) : null,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightMint)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightMint)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _mint, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}
