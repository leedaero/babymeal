// lib/features/login/login_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../shell/main_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthStorage.serverUrl.then((v) {
      if (v != null && mounted) _serverCtrl.text = v;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        _serverCtrl.text.trim(),
        _userCtrl.text.trim(),
        _passCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      final msg = e is DioException && e.response?.statusCode == 401
          ? '아이디 또는 비밀번호가 올바르지 않습니다.'
          : e is DioException
              ? '서버에 연결할 수 없습니다. URL을 확인해 주세요.'
              : '로그인 중 오류가 발생했습니다.';
      setState(() { _error = msg; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text('🍼 치밀한 이유식',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _serverCtrl,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _userFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: '서버 URL',
                      hintText: 'https://babymeal.example.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'URL을 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _userCtrl,
                    focusNode: _userFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: '아이디',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '아이디를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('로그인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _serverCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    _userFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }
}
