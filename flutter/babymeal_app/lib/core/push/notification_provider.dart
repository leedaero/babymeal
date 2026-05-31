// lib/core/push/notification_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_model.dart';
import 'notification_store.dart';

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  StreamSubscription<RemoteMessage>? _sub;

  @override
  Future<List<AppNotification>> build() async {
    ref.onDispose(() => _sub?.cancel());

    _sub = FirebaseMessaging.onMessage.listen((msg) async {
      final n = AppNotification(
        id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: msg.notification?.title ?? '알림',
        body: msg.notification?.body ?? '',
        type: _typeFrom(msg.data),
        createdAt: DateTime.now(),
      );
      await NotificationStore.add(n);
      final fresh = await NotificationStore.loadAll();
      state = AsyncValue.data(fresh);
    });

    return NotificationStore.loadAll();
  }

  Future<void> markRead(String id) async {
    final current = state.value ?? [];
    final updated = current
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    state = AsyncValue.data(updated);
    await NotificationStore.saveAll(updated);
  }

  Future<void> markAllRead() async {
    final current = state.value ?? [];
    final updated = current.map((n) => n.copyWith(isRead: true)).toList();
    state = AsyncValue.data(updated);
    await NotificationStore.saveAll(updated);
  }

  static String _typeFrom(Map<String, dynamic> data) {
    final raw = (data['type'] ?? data['screen'] ?? '').toString();
    if (raw == 'schedule') return 'schedule';
    return 'inventory';
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(
  NotificationNotifier.new,
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).value?.where((n) => !n.isRead).length ?? 0;
});
