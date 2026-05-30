// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../login/login_screen.dart';
import 'settings_provider.dart';

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
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(auth.username),
            subtitle: auth.isAdmin ? const Text('관리자') : null,
          ),
          const Divider(),
          if (auth.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('알림 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNotificationSettings(context),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('사용자 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openUserManagement(context),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('서버 URL 변경'),
            onTap: () => _changeServerUrl(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _changeServerUrl(BuildContext context) async {
    final current = await AuthStorage.serverUrl ?? '';
    if (!context.mounted) return;
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('서버 URL 변경'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'URL', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await AuthStorage.saveServerUrl(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('서버 URL 저장됨')));
      }
    }
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    final settingsAsync =
        await ref.read(notificationSettingsProvider.future).catchError((_) => <String, dynamic>{});
    if (!context.mounted) return;
    final webhookCtrl = TextEditingController(
        text: settingsAsync['discord_webhook'] ?? '');
    final thresholdCtrl = TextEditingController(
        text: (settingsAsync['notify_threshold'] ?? 3).toString());
    bool enabled = settingsAsync['enabled'] ?? false;
    int hour = settingsAsync['notify_hour'] ?? 8;
    int minute = settingsAsync['notify_minute'] ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('알림 설정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('매일 알림 사용'),
                  value: enabled,
                  onChanged: (v) => setSt(() => enabled = v),
                ),
                if (enabled)
                  Row(children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: hour,
                        items: List.generate(24, (i) => DropdownMenuItem(
                            value: i, child: Text('$i시'))),
                        onChanged: (v) => setSt(() => hour = v!),
                      ),
                    ),
                    Expanded(
                      child: DropdownButton<int>(
                        value: minute,
                        items: [0, 15, 30, 45].map((m) => DropdownMenuItem(
                            value: m, child: Text('$m분'))).toList(),
                        onChanged: (v) => setSt(() => minute = v!),
                      ),
                    ),
                  ]),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '재고 부족 기준 큐브 수',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: webhookCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Discord 웹훅 URL',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () async {
                  try {
                    await SettingsActions.testNotification();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('테스트 알림 전송됨')));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('실패: $e')));
                    }
                  }
                },
                child: const Text('테스트')),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SettingsActions.saveNotificationSettings({
                    'enabled': enabled,
                    'notify_hour': hour,
                    'notify_minute': minute,
                    'notify_threshold':
                        int.tryParse(thresholdCtrl.text) ?? 3,
                    'discord_webhook': webhookCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserManagement(BuildContext context) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _UserManagementScreen(),
    ));
  }
}

class _UserManagementScreen extends ConsumerStatefulWidget {
  const _UserManagementScreen();
  @override
  ConsumerState<_UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<_UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _users = await SettingsActions.getUsers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('사용자 관리'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _addUser(context),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  return ListTile(
                    title: Text(u['username'] ?? ''),
                    subtitle: Text(u['is_active'] == 1 ? '활성' : '비활성'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(u['is_active'] == 1
                              ? Icons.block
                              : Icons.check_circle),
                          onPressed: () async {
                            await SettingsActions.toggleUser(u['id']);
                            _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await SettingsActions.deleteUser(u['id']);
                            _load();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      );

  Future<void> _addUser(BuildContext context) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('사용자 추가'),
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
            onPressed: () async {
              try {
                await SettingsActions.addUser(
                    userCtrl.text.trim(), passCtrl.text);
                if (context.mounted) Navigator.pop(context);
                _load();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
