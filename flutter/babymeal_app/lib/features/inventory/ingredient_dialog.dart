// lib/features/inventory/ingredient_dialog.dart
import 'package:flutter/material.dart';
import 'ingredient_model.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

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

// ── 이모지 검색 다이얼로그 (B안) ──────────────────────────
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
            // 타이틀
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

            // 검색창
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
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF7FAF8),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              ),
            ),
            const SizedBox(height: 10),

            // 결과 개수
            Text(
              results.isEmpty ? '검색 결과 없음' : '${results.length}개',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),

            // 결과 리스트
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('😅 찾는 재료가 없어요', style: TextStyle(color: Colors.grey)),
                      ),
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
                                  decoration: BoxDecoration(
                                    color: _lightMint,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(item['e']!, style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['ko']!,
                                        style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
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

// ── 재료 추가/수정 다이얼로그 ────────────────────────────
class IngredientDialog extends StatefulWidget {
  final Ingredient? existing;
  const IngredientDialog({super.key, this.existing});

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  final _nameCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _unitType = 'weight';
  String _emoji = '';

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
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    }
  }

  Future<void> _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => const _EmojiPickerDialog(),
    );
    if (picked != null) setState(() => _emoji = picked);
  }

  Map<String, dynamic> toData() => {
        'name': _nameCtrl.text.trim(),
        'emoji': _emoji,
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

                // 이모지 버튼 + 이름 가로 배치
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이모지 탭 버튼
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
    for (final c in [_nameCtrl, _totalCtrl, _weightCtrl, _dateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }
}
