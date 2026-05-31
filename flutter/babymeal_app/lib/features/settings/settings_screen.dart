// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../login/login_screen.dart';
import 'settings_provider.dart';

const _green = Color(0xFF2d6a4f);
const _mint = Color(0xFF52b788);
const _lightMint = Color(0xFFd8f3dc);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(title: const Text('설정'), backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(auth.username, auth.isAdmin),
          const SizedBox(height: 20),
          if (auth.isAdmin) ...[
            _sectionTitle('관리'),
            _buildGroup([
              _SettingItem(
                icon: Icons.notifications_outlined,
                iconBg: _lightMint,
                iconColor: _green,
                label: '알림 설정',
                onTap: () => _openNotificationSettings(context),
              ),
              _SettingItem(
                icon: Icons.people_outline,
                iconBg: const Color(0xFFe8f4fd),
                iconColor: const Color(0xFF457b9d),
                label: '사용자 관리',
                onTap: () => _openUserManagement(context),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          _sectionTitle('계정'),
          _buildGroup([
            _SettingItem(
              icon: Icons.logout,
              iconBg: const Color(0xFFffe5e7),
              iconColor: const Color(0xFFe63946),
              label: '로그아웃',
              labelColor: const Color(0xFFe63946),
              onTap: () => _logout(context),
              showArrow: false,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String username, bool isAdmin) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_mint, _green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(child: Text('👶', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(isAdmin ? '관리자 계정' : '일반 계정',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
      );

  Widget _buildGroup(List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, indent: 56),
              _buildSettingTile(item),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingTile(_SettingItem item) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: item.iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(item.icon, color: item.iconColor, size: 18),
        ),
        title: Text(item.label,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: item.labelColor ?? const Color(0xFF1b4332),
            )),
        trailing: item.showArrow
            ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
            : null,
        onTap: item.onTap,
      );

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe63946)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    final settingsAsync =
        await ref.read(notificationSettingsProvider.future).catchError((_) => <String, dynamic>{});
    if (!context.mounted) return;
    final webhookCtrl = TextEditingController(text: settingsAsync['discord_webhook'] ?? '');
    final thresholdCtrl = TextEditingController(text: (settingsAsync['notify_threshold'] ?? 3).toString());
    bool enabled = settingsAsync['enabled'] ?? false;
    int hour = settingsAsync['notify_hour'] ?? 8;
    int minute = settingsAsync['notify_minute'] ?? 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.w800, color: _green)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('매일 알림 사용'),
                  value: enabled,
                  activeColor: _mint,
                  onChanged: (v) => setSt(() => enabled = v),
                ),
                if (enabled)
                  Row(children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: hour,
                        items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i시'))),
                        onChanged: (v) => setSt(() => hour = v!),
                      ),
                    ),
                    Expanded(
                      child: DropdownButton<int>(
                        value: minute,
                        items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('$m분'))).toList(),
                        onChanged: (v) => setSt(() => minute = v!),
                      ),
                    ),
                  ]),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '재고 부족 기준 큐브 수', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: webhookCtrl,
                  decoration: const InputDecoration(labelText: 'Discord 웹훅 URL', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await SettingsActions.testNotification();
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('테스트 알림 전송됨')));
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('실패: $e')));
                }
              },
              child: const Text('테스트'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              onPressed: () async {
                try {
                  await SettingsActions.saveNotificationSettings({
                    'enabled': enabled,
                    'notify_hour': hour,
                    'notify_minute': minute,
                    'notify_threshold': int.tryParse(thresholdCtrl.text) ?? 3,
                    'discord_webhook': webhookCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
                }
              },
              child: const Text('저장', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    webhookCtrl.dispose();
    thresholdCtrl.dispose();
  }

  Future<void> _openUserManagement(BuildContext context) async {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _UserManagementScreen()));
  }
}

class _SettingItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;
  final bool showArrow;
  const _SettingItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.onTap,
    this.showArrow = true,
  });
}

class _UserManagementScreen extends ConsumerStatefulWidget {
  const _UserManagementScreen();
  @override
  ConsumerState<_UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<_UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _users = await SettingsActions.getUsers(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('사용자 관리'),
          actions: [
            IconButton(icon: const Icon(Icons.person_add), onPressed: () => _addUser(context)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _mint))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _lightMint, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person_outline, color: _green, size: 18),
                      ),
                      title: Text(u['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(u['is_active'] == 1 ? '활성' : '비활성',
                          style: TextStyle(color: u['is_active'] == 1 ? _mint : Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(u['is_active'] == 1 ? Icons.block : Icons.check_circle,
                                color: u['is_active'] == 1 ? Colors.orange : _mint),
                            onPressed: () async { await SettingsActions.toggleUser(u['id']); _load(); },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFe63946)),
                            onPressed: () async { await SettingsActions.deleteUser(u['id']); _load(); },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );

  Future<void> _addUser(BuildContext context) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('사용자 추가', style: TextStyle(fontWeight: FontWeight.w800, color: _green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: userCtrl,
                decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              try {
                await SettingsActions.addUser(userCtrl.text.trim(), passCtrl.text);
                if (context.mounted) Navigator.pop(context);
                _load();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 실패: $e')));
              }
            },
            child: const Text('추가', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    userCtrl.dispose();
    passCtrl.dispose();
  }
}
