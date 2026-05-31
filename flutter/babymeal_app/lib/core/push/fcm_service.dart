// lib/core/push/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/api_client.dart';
import 'notification_model.dart';
import 'notification_store.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  final n = AppNotification(
    id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: message.notification?.title ?? '알림',
    body: message.notification?.body ?? '',
    type: (message.data['type'] ?? '') == 'schedule' ? 'schedule' : 'inventory',
    createdAt: DateTime.now(),
  );
  await NotificationStore.add(n);
}

class FcmService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'babymeal_alerts',
    '치밀한 이유식 알림',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _localNotif.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            importance: Importance.high,
          ),
        ),
      );
    });
    await FirebaseMessaging.instance.requestPermission();
  }

  static Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await ApiClient.instance.dio
          .post('/api/push/fcm-token', data: {'token': token});
    } catch (_) {}
  }

  static Future<void> unregisterToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await ApiClient.instance.dio
          .delete('/api/push/fcm-token', data: {'token': token});
    } catch (_) {}
    await FirebaseMessaging.instance.deleteToken();
  }
}
