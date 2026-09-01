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

  // Firebase公式ではネイティブGoogleログインにgoogle_sign_inが必要。
  // 公開済みAndroidの経路はこのiOS準備では変更せず、iOSではOS標準の
  // Appleログインだけを表示する。
  static bool get _showGoogle =>
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS);

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
              'クラウドアカウント',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '機種変更や端末の故障に備えて、記録をクラウドに'
              '保存するためと、既存アカウントの管理・削除に使います。\n'
              'オンライン自動バックアップはPro版の機能です。\n'
              'Pro版のお支払いは App Store・Google Play で'
              '行い、ここでのサインインは不要です。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            if (_showGoogle)
              _SignInButton(
                label: 'Googleで続ける',
                leading: const _GoogleMark(),
                onPressed: () =>
                    _signIn(context, CloudBackup.instance.signInWithGoogle),
              ),
            if (_showApple) ...[
              if (_showGoogle) const SizedBox(height: 10),
              _SignInButton(
                label: 'Appleでサインイン',
                icon: Icons.apple,
                appleStyle: true,
                onPressed: () => _signIn(
                  context,
                  CloudBackup.instance.signInWithApple,
                ),
              ),
              if (!_showGoogle) ...[
                const SizedBox(height: 12),
                Text(
                  'Android版のGoogleアカウントとは別の保存先です。Androidから'
                  '記録を移す場合は、先にファイルへバックアップしてiPhoneで'
                  '読み込んでください。Pro購入はGoogle Playから'
                  'App Storeへ引き継がれません。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
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
    this.icon,
    this.leading,
    this.appleStyle = false,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool appleStyle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: 10),
        ],
        Text(label),
      ],
    );
    if (appleStyle) {
      // Appleのcustom button寸法・配色へ合わせる。最終的なlogo/余白は
      // 実機で最新HIGと照合してから提出する。
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: content,
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
