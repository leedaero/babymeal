// lib/features/settings/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

final notificationSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final resp =
      await ApiClient.instance.dio.get('/api/notification-settings');
  return Map<String, dynamic>.from(resp.data as Map);
});

class SettingsActions {
  static Future<void> saveNotificationSettings(
      Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/notification-settings', data: data);
  }

  static Future<void> testNotification() async {
    await ApiClient.instance.dio
        .post('/api/notification-settings/test');
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final resp = await ApiClient.instance.dio.get('/api/users');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }

  static Future<void> addUser(String username, String password) async {
    await ApiClient.instance.dio.post('/api/users',
        data: {'username': username, 'password': password});
  }

  static Future<void> deleteUser(int id) async {
    await ApiClient.instance.dio.delete('/api/users/$id');
  }

  static Future<void> toggleUser(int id) async {
    await ApiClient.instance.dio.post('/api/users/$id/toggle-active');
  }
}
