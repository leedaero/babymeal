// lib/core/auth/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_storage.dart';
import '../api/api_client.dart';
import '../push/fcm_service.dart';

class AuthState {
  final bool isLoggedIn;
  final String username;
  final bool isAdmin;
  const AuthState({
    this.isLoggedIn = false,
    this.username = '',
    this.isAdmin = false,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // Token existence is sufficient here — expiry is handled transparently by the
  // ApiClient 401 interceptor. If the refresh token is also expired, the first
  // API call will fail with a 401 and the caller must invoke logout().
  Future<void> checkAuth() async {
    final token = await AuthStorage.accessToken;
    if (token == null) { state = const AuthState(); return; }
    state = AuthState(
      isLoggedIn: true,
      username: await AuthStorage.username ?? '',
      isAdmin: await AuthStorage.isAdmin,
    );
  }

  Future<void> login(String serverUrl, String username, String password) async {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    await AuthStorage.saveServerUrl(cleanUrl);
    final resp = await ApiClient.instance.dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    await AuthStorage.saveTokens(
      accessToken: resp.data['access_token'],
      refreshToken: resp.data['refresh_token'],
      username: resp.data['username'],
      isAdmin: resp.data['is_admin'] ?? false,
    );
    await FcmService.registerToken();
    state = AuthState(
      isLoggedIn: true,
      username: resp.data['username'],
      isAdmin: resp.data['is_admin'] ?? false,
    );
  }

  Future<void> logout() async {
    final rt = await AuthStorage.refreshToken;
    if (rt != null) {
      try {
        await ApiClient.instance.dio
            .post('/api/auth/logout', data: {'refresh_token': rt});
      } catch (_) {}
    }
    await FcmService.unregisterToken();
    await AuthStorage.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
