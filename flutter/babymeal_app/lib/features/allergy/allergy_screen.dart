// lib/features/allergy/allergy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'allergy_provider.dart';
import 'allergy_model.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

class AllergyScreen extends ConsumerStatefulWidget {
  const AllergyScreen({super.key});
  @override
  ConsumerState<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends ConsumerState<AllergyScreen>
    with WidgetsBindingObserver {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(allergyProvider);
  }

  String get _selectedStr => _selected.toIso8601String().substring(0, 10);

  String get _selectedLabel {
    final now = DateTime.now();
    if (isSameDay(_selected, now)) return '오늘 테스트';
    return '${_selected.month}월 ${_selected.day}일 테스트';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allergyProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('알러지 테스트'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: _lightMint, borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.add, color: _green, size: 18),
                onPressed: () => _add(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (tests) {
          final byDate = <String, List<AllergyTest>>{};
          for (final t in tests) {
            byDate.putIfAbsent(t.testDate, () => []).add(t);
          }
          final dayTests = byDate[_selectedStr] ?? [];
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
                    todayTextStyle: const TextStyle(
                        color: _green, fontWeight: FontWeight.w800),
                    selectedDecoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedTextStyle: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                    markerDecoration: const BoxDecoration(
                        color: _mint, shape: BoxShape.circle),
                    markerSize: 5,
                    weekendTextStyle:
                        const TextStyle(color: Color(0xFFe63946)),
                    defaultTextStyle: const TextStyle(color: Color(0xFF333333)),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey),
                    weekendStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFe63946)),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _mint)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: dayTests.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🧪',
                                        style: TextStyle(fontSize: 40)),
                                    const SizedBox(height: 8),
                                    const Text('이날 테스트가 없어요',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 14)),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () => _add(context),
                                      icon: const Icon(Icons.add, color: _mint),
                                      label: const Text('테스트 추가',
                                          style: TextStyle(color: _mint)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: dayTests.length,
                                itemBuilder: (_, i) => _AllergyCard(
                                  test: dayTests[i],
                                  onRefresh: () =>
                                      ref.invalidate(allergyProvider),
                                  onEdit: () => _edit(context, dayTests[i]),
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

  Future<void> _add(BuildContext context) async {
    final data = await _showSheet(context, null);
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

  Future<void> _edit(BuildContext context, AllergyTest existing) async {
    final data = await _showSheet(context, existing);
    if (data == null) return;
    try {
      await AllergyActions.update(existing.id, data);
      ref.invalidate(allergyProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      }
    }
  }

  Future<Map<String, dynamic>?> _showSheet(
      BuildContext context, AllergyTest? existing) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllergySheet(
        selectedDate: _selectedStr,
        existing: existing,
      ),
    );
  }
}

// ── 입력 시트 ─────────────────────────────────────────────────────────────────
class _AllergySheet extends StatefulWidget {
  final String selectedDate;
  final AllergyTest? existing;
  const _AllergySheet({required this.selectedDate, this.existing});

  @override
  State<_AllergySheet> createState() => _AllergySheetState();
}

class _AllergySheetState extends State<_AllergySheet> {
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _emojiCtrl =
        TextEditingController(text: widget.existing?.emoji ?? '🧪');
    _nameCtrl =
        TextEditingController(text: widget.existing?.ingredientName ?? '');
    _memoCtrl =
        TextEditingController(text: widget.existing?.memo ?? '');
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('재료명을 입력해주세요'),
        backgroundColor: const Color(0xFFe63946),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    Navigator.pop(context, {
      'test_date': widget.selectedDate,
      'emoji': _emojiCtrl.text.trim().isEmpty ? '🧪' : _emojiCtrl.text.trim(),
      'ingredient_name': _nameCtrl.text.trim(),
      'memo': _memoCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // gradient header
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
                      child: const Icon(Icons.science, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? '테스트 수정' : '알러지 테스트 추가',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.selectedDate,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // form
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // emoji field
                    GestureDetector(
                      onTap: () => _nameCtrl.selection = TextSelection.collapsed(offset: 0),
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: _lightMint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _emojiCtrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            maxLength: 2,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Field(
                        controller: _nameCtrl,
                        label: '재료명',
                        hint: '예) 당근',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _memoCtrl,
                  label: '반응 메모',
                  hint: '예) 두드러기, 이상 없음 등',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _submit,
                    child: Text(
                      isEdit ? '수정 완료' : '테스트 저장',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _mint, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

// ── 알러지 카드 ───────────────────────────────────────────────────────────────
class _AllergyCard extends StatelessWidget {
  final AllergyTest test;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  const _AllergyCard(
      {required this.test, required this.onRefresh, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasMemo = test.memo.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _lightMint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(test.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.ingredientName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _green)),
                  if (hasMemo) ...[
                    const SizedBox(height: 3),
                    Text(test.memo,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) async {
                if (v == 'edit') {
                  onEdit();
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      content: Text('${test.ingredientName} 테스트를 삭제할까요?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFe63946)),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await AllergyActions.delete(test.id);
                    onRefresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('삭제 실패: $e')));
                    }
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정 ✏️')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제',
                        style: TextStyle(color: Color(0xFFe63946)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
