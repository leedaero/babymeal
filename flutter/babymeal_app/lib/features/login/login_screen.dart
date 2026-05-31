// lib/features/login/login_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../shell/main_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _serverUrl = 'https://baby.daero.me';
  static const _green = Color(0xFF2d6a4f);
  static const _mint = Color(0xFF52b788);
  static const _lightMint = Color(0xFFd8f3dc);

  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        _serverUrl,
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
              ? '서버에 연결할 수 없습니다.'
              : '로그인 중 오류가 발생했습니다.';
      setState(() { _error = msg; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFd8f3dc), Color(0xFFb7e4c7), Color(0xFF95d5b2)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🍼', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 8),
                    const Text('치밀한 이유식',
                        style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, color: _green,
                        )),
                    const SizedBox(height: 4),
                    const Text('이유식 재고 & 식단 관리',
                        style: TextStyle(fontSize: 13, color: _mint)),
                    const SizedBox(height: 36),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24, offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('아이디'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _userCtrl,
                              focusNode: _userFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _passFocus.requestFocus(),
                              decoration: _inputDeco('아이디 입력', Icons.person_outline),
                              validator: (v) => (v == null || v.isEmpty) ? '아이디를 입력하세요' : null,
                            ),
                            const SizedBox(height: 20),
                            _fieldLabel('비밀번호'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: _inputDeco('비밀번호 입력', Icons.lock_outline).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: _mint),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFffe5e7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFe63946), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!,
                                        style: const TextStyle(color: Color(0xFFe63946), fontSize: 13))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: _loading ? null : const LinearGradient(
                                    colors: [_mint, _green],
                                  ),
                                  color: _loading ? Colors.grey.shade300 : null,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _loading ? [] : [
                                    BoxShadow(
                                      color: _mint.withOpacity(0.4),
                                      blurRadius: 12, offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('로그인',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _mint, letterSpacing: 0.5,
        ),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _mint, size: 20),
        filled: true,
        fillColor: _lightMint.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightMint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightMint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _mint, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFe63946)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFe63946), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose();
    _userFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }
}
