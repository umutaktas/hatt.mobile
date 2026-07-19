import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(userStateProvider).value;
    final repo = ref.read(userRepositoryProvider);
    final tokenStore = ref.watch(authTokenStoreProvider);

    final isRegistered = tokenStore.accountType == 'registered';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.settingsSound),
            secondary: const Icon(Icons.volume_up),
            value: user?.soundEnabled ?? true,
            onChanged: (v) => repo.setSoundEnabled(v),
          ),
          SwitchListTile(
            title: Text(l10n.settingsHarakat),
            secondary: const Icon(Icons.text_fields),
            value: user?.showHarakat ?? true,
            onChanged: (v) => repo.setShowHarakat(v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: AppColors.ink),
            title: const Text('İlerlemeyi Bulutla Eşitle'),
            subtitle: Text(
              _isSyncing ? 'Eşitleniyor...' : 'Verilerin sunucuya yedeklenir.',
            ),
            trailing: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isSyncing ? null : _handleSync,
          ),
          ListTile(
            leading: Icon(
              isRegistered ? Icons.verified_user : Icons.account_circle,
              color: isRegistered ? AppColors.success : AppColors.gold,
            ),
            title: Text(
              isRegistered ? 'Hesap Kalıcı Hale Geldi' : 'Hesabını E-posta ile Bağla',
            ),
            subtitle: Text(
              isRegistered
                  ? 'Cihaz değiştirsen de ilerlemen korunur.'
                  : 'Anonim hesabını korumak için e-posta bağla.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAccountLinkingDialog(context),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Premium (geliştirici)'),
            subtitle: const Text('Satın alma akışı feature flag arkasında'),
            secondary: const Icon(Icons.workspace_premium, color: AppColors.gold),
            value: user?.premium ?? false,
            onChanged: (v) => repo.setPremium(v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.error),
            title: Text(
              l10n.settingsDeleteAccount,
              style: const TextStyle(color: AppColors.error),
            ),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final syncService = ref.read(progressSyncServiceProvider);
    final result = await syncService.uploadProgress();

    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'İlerleme sunucuya başarıyla yedeklendi.'
              : 'Senkronizasyon hatası: ${result.error ?? "Sunucuya ulaşılamadı."}',
        ),
      ),
    );
  }

  Future<void> _showAccountLinkingDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final linkingService = ref.read(accountLinkingServiceProvider);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabını E-posta ile Bağla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Şifre (min 8 karakter)'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              if (email.isEmpty || password.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen geçerli e-posta ve şifre girin.')),
                );
                return;
              }

              final res = await linkingService.linkEmail(
                email: email,
                password: password,
              );

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res.success
                          ? 'Hesap başarıyla bağlandı!'
                          : 'Hata: ${res.error}',
                    ),
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Bağla'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteAccount),
        content: const Text(
          'Tüm ilerlemen, yerel verilerin ve sunucu hesabın kalıcı olarak silinecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Delete on backend first
    await ref.read(accountLinkingServiceProvider).deleteAccount();
    // Delete local user data
    await ref.read(userRepositoryProvider).deleteAllUserData();

    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}
