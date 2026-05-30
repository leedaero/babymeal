// lib/features/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ingredient_provider.dart';
import 'ingredient_model.dart';
import 'ingredient_dialog.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('재고현황')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addIngredient(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('등록된 재료가 없어요'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) =>
                    _IngredientTile(item: items[i], onRefresh: () {
                      ref.invalidate(ingredientsProvider);
                    }),
              ),
      ),
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

class _IngredientTile extends StatelessWidget {
  final Ingredient item;
  final VoidCallback onRefresh;
  const _IngredientTile({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    final low = item.isLowStock;
    return ListTile(
      leading: Text(item.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(item.name,
          style: TextStyle(color: expired ? Colors.red : null)),
      subtitle: Text('${item.currentCubes}개 남음'
          '${expired ? ' · 유통기한 초과' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (low)
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 18),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _adjust(context, -1),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _adjust(context, 1),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(value: 'logs', child: Text('로그')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, int delta) async {
    try {
      await IngredientActions.adjust(item.id, delta);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('조정 실패: $e')));
      }
    }
  }

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'edit') {
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
          title: const Text('재료 삭제'),
          content: Text('${item.name}을 삭제하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
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
        builder: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${item.emoji} ${item.name} 로그',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final l = logs[i];
                  return ListTile(
                    title: Text('${l['event_type']} ${l['delta'] > 0 ? '+' : ''}${l['delta']}'),
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
