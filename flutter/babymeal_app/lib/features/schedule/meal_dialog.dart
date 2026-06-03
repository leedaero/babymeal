// lib/features/schedule/meal_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inventory/ingredient_model.dart';
import '../inventory/ingredient_provider.dart';
import 'meal_model.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

// 정렬: 베이스(0) → 소(1) → 닭(2) → 나머지(3)
int _priority(String name) {
  if (name.contains('베이스')) return 0;
  if (name.contains('소')) return 1;
  if (name.contains('닭')) return 2;
  return 3;
}

List<Ingredient> _sorted(List<Ingredient> items) {
  final list = [...items];
  list.sort((a, b) {
    final d = _priority(a.name) - _priority(b.name);
    return d != 0 ? d : a.name.compareTo(b.name);
  });
  return list;
}

const _times = [
  ('morning',       '🌅 아침'),
  ('morning_snack', '🍪 오전간식'),
  ('lunch',         '☀️ 점심'),
  ('snack',         '🍪 오후간식'),
  ('dinner',        '🌙 저녁'),
];

class MealDialog extends ConsumerStatefulWidget {
  final String initialDate;
  final Meal? existing; // null = 추가, non-null = 수정
  const MealDialog({super.key, required this.initialDate, this.existing});

  @override
  ConsumerState<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends ConsumerState<MealDialog> {
  String _mealTime = 'morning';
  final _searchCtrl = TextEditingController();
  String _query = '';
  // ingredientId → 수량(큐브 수)
  final Map<int, int> _selected = {};

  bool get _isEdit => widget.existing != null;
  int get _totalCount => _selected.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _mealTime = e.mealTime;
      for (final ing in e.ingredients) {
        _selected[ing.ingredientId] = ing.grams;
      }
    }
  }

  Map<String, dynamic> toData() => {
        'date': widget.initialDate,
        'meal_time': _mealTime,
        'note': '',
        'ingredients': _selected.entries
            .map((e) => {'ingredient_id': e.key, 'grams': e.value})
            .toList(),
      };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ingredientsProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.91,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSelectedPanel(async),
          _buildSearch(),
          Expanded(child: _buildGrid(async)),
          _buildFooter(context),
        ],
      ),
    );
  }

  // ── ① 그라디언트 헤더 ────────────────────────────────
  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_mint, _green]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isEdit ? '식단 수정' : '식단 추가',
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      Text(widget.initialDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          )),
                    ],
                  ),
                ),
                if (_totalCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('총 $_totalCount 큐브',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _times.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final (value, label) = _times[i];
                  final on = _mealTime == value;
                  return GestureDetector(
                    onTap: () => setState(() => _mealTime = value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: on
                            ? Colors.white.withOpacity(0.92)
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(label,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: on ? _green : Colors.white.withOpacity(0.85),
                          )),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  // ── ② 선택된 재료 패널 ───────────────────────────────
  Widget _buildSelectedPanel(AsyncValue<List<Ingredient>> async) =>
      Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1.5)),
        ),
        child: _selected.isEmpty
            ? Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('탭 = +1큐브   길게 누르면 제거',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('선택된 재료',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: _lightMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_selected.length}종  $_totalCount큐브',
                            style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: _green,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  async.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (items) {
                      final selItems = _sorted(items)
                          .where((i) => _selected.containsKey(i.id))
                          .toList();
                      return SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: selItems.map((ing) {
                            final cnt = _selected[ing.id]!;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selected[ing.id] = cnt + 1),
                                onLongPress: () =>
                                    setState(() => _selected.remove(ing.id)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _lightMint,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _mint.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${ing.emoji} ${ing.name}'
                                        '${ing.weightPerCube != null ? ' ${ing.weightPerCube}g' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _green,
                                          )),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _green,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('×$cnt',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            )),
                                      ),
                                      const SizedBox(width: 3),
                                      Text('✕',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade400,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
      );

  // ── ③ 검색창 ─────────────────────────────────────────
  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '재료 검색...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            prefixIcon: const Icon(Icons.search, color: _mint, size: 18),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _query = '';
                    }),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7FAF8),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _lightMint)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _lightMint)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _mint, width: 2)),
          ),
        ),
      );

  // ── ④ 재료 칩 그리드 (탭=+1, 길게누르기=제거) ────────
  Widget _buildGrid(AsyncValue<List<Ingredient>> async) => async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _mint)),
        error: (e, _) => Center(child: Text('재료 로드 실패: $e')),
        data: (items) {
          final list = _sorted(items);
          final filtered = _query.isEmpty
              ? list
              : list
                  .where((i) =>
                      i.name.contains(_query) || i.emoji.contains(_query))
                  .toList();

          if (filtered.isEmpty) {
            return Center(
                child: Text('검색 결과가 없어요',
                    style: TextStyle(color: Colors.grey.shade400)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: filtered.map((ing) {
                final cnt = _selected[ing.id] ?? 0;
                final sel = cnt > 0;
                return GestureDetector(
                  onTap: () => setState(
                      () => _selected[ing.id] = cnt + 1),
                  onLongPress: () =>
                      setState(() => _selected.remove(ing.id)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _lightMint : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: sel ? _mint : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: _mint.withOpacity(0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${ing.emoji} ${ing.name}'
                          '${ing.weightPerCube != null ? ' ${ing.weightPerCube}g' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _green : Colors.grey.shade700,
                          ),
                        ),
                        if (sel) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('×$cnt',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                )),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      );

  // ── ⑤ 하단 버튼 ──────────────────────────────────────
  Widget _buildFooter(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _lightMint, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('취소',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _selected.isEmpty
                      ? null
                      : const LinearGradient(colors: [_mint, _green]),
                  color: _selected.isEmpty ? Colors.grey.shade200 : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selected.isEmpty
                      ? null
                      : [
                          BoxShadow(
                            color: _green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, toData()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isEdit ? '수정 완료' : '저장',
                        style: TextStyle(
                          color: _selected.isEmpty
                              ? Colors.grey.shade400
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$_totalCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              )),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
