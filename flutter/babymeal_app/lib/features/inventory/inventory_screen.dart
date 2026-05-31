// lib/features/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/push/fcm_service.dart';
import 'ingredient_provider.dart';
import 'ingredient_model.dart';
import 'ingredient_dialog.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

const _categories = ['전체', '채소', '과일', '단백질', '곡물', '유제품', '기타'];

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with WidgetsBindingObserver {
  String _search = '';
  String _category = '전체';

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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(ingredientsProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ingredientsProvider);
    await ref.read(ingredientsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ingredientsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('재고 관리'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: _green, size: 18),
                onPressed: () => _showPushStatus(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addIngredient(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          final filtered = items.where((item) {
            final matchSearch = _search.isEmpty ||
                item.name.contains(_search) ||
                item.emoji.contains(_search);
            final matchCat = _category == '전체' || item.unitType == _category;
            return matchSearch && matchCat;
          }).toList();

          return Column(
            children: [
              _buildSearchBar(),
              _buildCategoryChips(),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🥕', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('등록된 재료가 없어요',
                                style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: _mint,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _IngredientCard(
                            item: filtered[i],
                            onRefresh: () => ref.invalidate(ingredientsProvider),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: '재료 검색...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );

  Widget _buildCategoryChips() => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final selected = _category == cat;
            return GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? _green : _lightMint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(cat,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _green,
                    )),
              ),
            );
          },
        ),
      );

  Future<void> _showPushStatus(BuildContext context) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final token = await FirebaseMessaging.instance.getToken();
    if (!context.mounted) return;

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PushStatusSheet(granted: granted, token: token),
    );
  }

  Future<void> _addIngredient(BuildContext context, WidgetRef ref) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const IngredientDialog(),
    );
    if (data == null) return;
    try {
      await IngredientActions.add(data);
      ref.invalidate(ingredientsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }
}

class _IngredientCard extends StatelessWidget {
  final Ingredient item;
  final VoidCallback onRefresh;
  const _IngredientCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final low = item.isLowStock;
    final expired = item.isExpired;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: expired
            ? Border.all(color: const Color(0xFFe63946).withOpacity(0.3))
            : low
                ? Border.all(color: Colors.orange.withOpacity(0.3))
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: expired
                    ? const Color(0xFFffe5e7)
                    : low
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFF0FAF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.name,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: expired ? const Color(0xFFe63946) : _green,
                          )),
                      const SizedBox(width: 6),
                      if (low && !expired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('부족',
                              style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
                        ),
                      if (expired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffe5e7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('만료',
                              style: TextStyle(fontSize: 10, color: Color(0xFFe63946), fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.unitType.isNotEmpty ? item.unitType : '보관 방법 미설정',
                      style: const TextStyle(fontSize: 12, color: _mint)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.currentCubes}',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: expired
                          ? const Color(0xFFe63946)
                          : low ? Colors.orange : _green,
                    )),
                const Text('큐브', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) => _onMenu(context, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'add', child: Text('재고 추가')),
                PopupMenuItem(value: 'remove', child: Text('재고 차감')),
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'logs', child: Text('로그')),
                PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Color(0xFFe63946)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'add' || action == 'remove') {
      final delta = action == 'add' ? 1 : -1;
      try {
        await IngredientActions.adjust(item.id, delta);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('조정 실패: $e')));
        }
      }
    } else if (action == 'edit') {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => IngredientDialog(existing: item),
      );
      if (data == null) return;
      try {
        await IngredientActions.update(item.id, data);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        }
      }
    } else if (action == 'logs') {
      _showLogs(context);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('재료 삭제'),
          content: Text('${item.name}을 삭제하시겠어요?'),
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
        await IngredientActions.delete(item.id);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    }
  }

  Future<void> _showLogs(BuildContext context) async {
    try {
      final logs = await IngredientActions.logs(item.id);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${item.emoji} ${item.name} 로그',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _green)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final l = logs[i];
                  final delta = l['delta'] as int;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: delta > 0 ? _lightMint : const Color(0xFFffe5e7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(delta > 0 ? Icons.add : Icons.remove,
                          color: delta > 0 ? _green : const Color(0xFFe63946), size: 18),
                    ),
                    title: Text('${l['event_type']} ${delta > 0 ? '+' : ''}$delta'),
                    subtitle: Text(l['logged_at']?.toString().substring(0, 16) ?? ''),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('로그 불러오기 실패: $e')));
      }
    }
  }
}

class _PushStatusSheet extends StatefulWidget {
  final bool granted;
  final String? token;
  const _PushStatusSheet({required this.granted, required this.token});

  @override
  State<_PushStatusSheet> createState() => _PushStatusSheetState();
}

class _PushStatusSheetState extends State<_PushStatusSheet> {
  late bool _enabled;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.granted && widget.token != null;
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      if (_enabled) {
        await FcmService.unregisterToken();
        setState(() => _enabled = false);
      } else {
        await FcmService.registerToken();
        setState(() => _enabled = true);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: widget.granted ? _lightMint : const Color(0xFFffe5e7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.granted ? Icons.notifications_active : Icons.notifications_off,
                  color: widget.granted ? _green : const Color(0xFFe63946),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.granted ? '알림 권한 허용됨' : '알림 권한 차단됨',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: widget.granted ? _green : const Color(0xFFe63946),
                    ),
                  ),
                  Text(
                    widget.granted ? '시스템에서 알림을 받을 수 있어요' : '설정에서 알림 권한을 허용해주세요',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('푸시 알림 수신',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
                    const SizedBox(height: 2),
                    Text(
                      _enabled ? '재고 부족·만료 알림을 받고 있어요' : '알림이 꺼져 있어요',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                _loading
                    ? const SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _mint),
                      )
                    : Switch(
                        value: _enabled,
                        onChanged: widget.granted ? (_) => _toggle() : null,
                        activeColor: _green,
                        activeTrackColor: _lightMint,
                      ),
              ],
            ),
          ),
          if (widget.token != null) ...[
            const SizedBox(height: 16),
            const Text('FCM 토큰', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.token!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('토큰이 복사되었어요'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _lightMint),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.token!,
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16, color: _mint),
                  ],
                ),
              ),
            ),
          ],
          if (!widget.granted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await FirebaseMessaging.instance.requestPermission();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('알림 권한 요청', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
