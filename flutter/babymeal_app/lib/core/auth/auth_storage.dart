// lib/core/auth/auth_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
    required bool isAdmin,
  }) =>
      Future.wait([
        _s.write(key: 'access_token', value: accessToken),
        _s.write(key: 'refresh_token', value: refreshToken),
        _s.write(key: 'username', value: username),
        _s.write(key: 'is_admin', value: isAdmin.toString()),
      ]);

  static Future<void> saveServerUrl(String url) =>
      _s.write(key: 'server_url', value: url);

  static Future<String?> get accessToken => _s.read(key: 'access_token');
  static Future<String?> get refreshToken => _s.read(key: 'refresh_token');
  static Future<String?> get serverUrl => _s.read(key: 'server_url');
  static Future<String?> get username => _s.read(key: 'username');
  static Future<bool> get isAdmin async =>
      (await _s.read(key: 'is_admin')) == 'true';

  static Future<void> clear() => _s.deleteAll();
}
