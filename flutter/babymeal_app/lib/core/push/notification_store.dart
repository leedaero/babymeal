// lib/core/push/notification_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_model.dart';

class NotificationStore {
  static const _key = 'app_notifications';
  static const _maxItems = 50;

  static Future<List<AppNotification>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = raw
        .map((s) {
          try {
            return AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppNotification>()
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<void> saveAll(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.take(_maxItems).map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  static Future<void> add(AppNotification n) async {
    final items = await loadAll();
    await saveAll([n, ...items]);
  }
}
