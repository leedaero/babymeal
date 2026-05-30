// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import '../auth/auth_storage.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  late final Dio dio;
  Future<bool>? _refreshFuture;

  ApiClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler h) async {
    final url = await AuthStorage.serverUrl ?? '';
    final token = await AuthStorage.accessToken;
    options.baseUrl = url;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    h.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    if (e.response?.statusCode == 401) {
      _refreshFuture ??= _tryRefresh().whenComplete(() => _refreshFuture = null);
      final ok = await _refreshFuture!;
      if (ok) {
        final opts = e.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${await AuthStorage.accessToken}';
        try {
          h.resolve(await dio.fetch(opts));
          return;
        } catch (_) {}
      }
    }
    h.next(e);
  }

  Future<bool> _tryRefresh() async {
    final serverUrl = await AuthStorage.serverUrl ?? '';
    final rt = await AuthStorage.refreshToken;
    if (rt == null || serverUrl.isEmpty) return false;
    try {
      final resp = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      )).post('$serverUrl/api/auth/refresh', data: {'refresh_token': rt});
      await AuthStorage.saveTokens(
        accessToken: resp.data['access_token'],
        refreshToken: resp.data['refresh_token'] ?? rt,
        username: await AuthStorage.username ?? '',
        isAdmin: await AuthStorage.isAdmin,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
