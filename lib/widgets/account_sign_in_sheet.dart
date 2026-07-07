import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../cloud/cloud_backup.dart';

/// オンラインバックアップ用のサインイン選択シート。
///
/// プロバイダが増えても「サインイン」1ボタンからここを開く形に統一する。
Future<void> showAccountSignInSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => const _AccountSignInSheet(),
  );
}

class _AccountSignInSheet extends StatelessWidget {
  const _AccountSignInSheet();

  static bool get _showApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'バックアップ用にサインイン',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '記録をクラウドに保存・復元するためのアカウントです。'
              '課金（Pro版の購入）とは別の手続きです。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            _SignInButton(
              label: 'Googleで続ける',
              icon: Icons.g_mobiledata_rounded,
              onPressed: () => _signIn(context, CloudBackup.instance.signInWithGoogle),
            ),
            if (_showApple) ...[
              const SizedBox(height: 10),
              _SignInButton(
                label: 'Appleで続ける',
                icon: Icons.apple,
                onPressed: () => _signIn(context, CloudBackup.instance.signInWithApple),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final err = await action();
    if (!context.mounted) return;
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (CloudBackup.instance.user.value != null) {
      navigator.pop();
    }
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
