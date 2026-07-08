import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/adaptive_layout.dart';
import '../backup/growth_backup.dart';
import '../cloud/cloud_backup.dart';
import '../models/child_profile.dart';
import '../monetization/pro_status.dart';
import '../settings/export_privacy.dart';
import '../widgets/account_sign_in_sheet.dart';
import '../support/contact_launcher.dart';
import 'about_app_screen.dart';
import 'birthday_memories_screen.dart';
import 'children_screen.dart';
import 'faq_screen.dart';
import 'privacy_policy_screen.dart';

/// 設定のトップ画面（メニュー形式）。
///
/// 以前はお子様一覧をそのまま並べていたが、項目が縦に長く見づらかったため
/// 「お子様の管理」「使い方・ヘルプ」「このアプリについて」の3セクションの
/// メニューにし、それぞれ別ページへ遷移する構成にした。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.children,
    required this.onUpdateChild,
    required this.onAddChild,
    required this.onReplayTutorial,
    required this.onRestoreChildren,
  });

  final List<ChildProfile> children;
  final void Function(int index, ChildProfile updated) onUpdateChild;
  final ValueChanged<ChildProfile> onAddChild;

  /// 「チュートリアルを見る」タップ時に呼ぶ（AppShell がガイドを再生する）。
  final VoidCallback onReplayTutorial;

  /// バックアップの読み込みで全データを置き換えるときに呼ぶ
  /// （AppShell が状態を差し替えて永続化する）。
  final ValueChanged<List<ChildProfile>> onRestoreChildren;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 設定タブはニュートラルテーマで描画されている。プッシュ先のページも
    // 同じ配色で揃うよう、現在のテーマを持ち回す。
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _sectionHeader('お子様'),
              _menuCard(context, [
                _menuTile(
                  context,
                  icon: Icons.family_restroom_rounded,
                  iconColor: scheme.primary,
                  title: 'プロフィール登録・修正',
                  subtitle: '登録済み ${children.length}名・お子様の追加もこちら',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Theme(
                          data: theme,
                          child: _ChildrenManagePage(
                            initialChildren: children,
                            onUpdateChild: onUpdateChild,
                            onAddChild: onAddChild,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                _menuTile(
                  context,
                  icon: Icons.cake_outlined,
                  iconColor: const Color(0xFFE8837B),
                  title: 'お誕生日の思い出',
                  subtitle: 'ご家族全員のアルバムをまとめて見返せます',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        // 設定系ページは子のテーマ色を使わないニュートラル配色。
                        builder: (_) => Theme(
                          data: theme,
                          child: BirthdayMemoriesScreen(
                            children: children,
                            onUpdateChild: onUpdateChild,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
              // バックアップは仕組みがわかりにくいため、見出し横の
              // インフォメーションから使い方（保存先・機種変更の手順）を出す。
              _sectionHeaderWithInfo(
                context,
                'データ管理',
                onInfo: () => _showBackupHowTo(context),
              ),
              _menuCard(context, [
                _menuTile(
                  context,
                  icon: Icons.save_alt_rounded,
                  iconColor: scheme.primary,
                  title: 'バックアップを書き出す',
                  subtitle: '全データを1つのファイルに保存（機種変更・控えに）',
                  onTap: () => _exportBackup(context),
                ),
                _menuTile(
                  context,
                  icon: Icons.settings_backup_restore_rounded,
                  iconColor: scheme.primary,
                  title: 'バックアップを読み込む',
                  subtitle: '書き出したファイルから復元（現在のデータは置き換え）',
                  onTap: () => _importBackup(context),
                ),
                // 書き出し物（受診レポート・サイズガイド画像）にだけ効く
                // プライバシー設定。アプリ内の表示は実名のまま。
                ValueListenableBuilder<bool>(
                  valueListenable: ExportPrivacy.maskNames,
                  builder: (context, mask, _) => SwitchListTile(
                    secondary: Icon(
                      Icons.visibility_off_outlined,
                      color: scheme.primary,
                    ),
                    title: const Text(
                      '書き出し時に名前を伏せる',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'レポートPDF・サイズガイド画像の名前を「第一子」'
                      '「第二子」…にします（登録中のお子様の生まれた順・'
                      '双子など同日生まれは登録順）',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: mask,
                    onChanged: (v) => ExportPrivacy.setEnabled(v),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _sectionHeader('Pro版'),
              _ProSection(
                childrenData: children,
                onRestoreChildren: onRestoreChildren,
              ),
              const SizedBox(height: 24),
              _sectionHeader('使い方・ヘルプ'),
              _menuCard(context, [
                _menuTile(
                  context,
                  icon: Icons.play_circle_outline,
                  iconColor: scheme.primary,
                  title: 'チュートリアルを見る',
                  subtitle: '初回に表示された使い方ガイドをもう一度見られます',
                  onTap: onReplayTutorial,
                ),
                _menuTile(
                  context,
                  icon: Icons.help_outline,
                  iconColor: scheme.primary,
                  title: 'Q&A・用語解説',
                  subtitle: 'SDスコアなどの用語や、各機能の予測の仕組み',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const FaqScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _sectionHeader('このアプリについて'),
              _menuCard(context, [
                _menuTile(
                  context,
                  icon: Icons.verified_outlined,
                  iconColor: scheme.primary,
                  title: 'データの根拠・免責事項',
                  subtitle: '成長曲線のもとになった公的データと、利用上の注意',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutAppScreen(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  iconColor: scheme.primary,
                  title: 'プライバシーポリシー',
                  subtitle: '個人情報・記録データの取り扱いについて',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  context,
                  icon: Icons.mail_outline_rounded,
                  iconColor: scheme.primary,
                  title: 'お問い合わせ',
                  subtitle: '不具合・ご要望・バックアップ・データ削除など',
                  onTap: () => openContactForm(context),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── バックアップ ─────────────────────────────────────────────────────────

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// 全データをバックアップファイル（.json）として保存する。
  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (children.isEmpty) {
      _showSnack(context, '保存するデータがありません');
      return;
    }
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      await FileSaver.instance.saveFile(
        name: '成長記録バックアップ_$stamp',
        bytes: Uint8List.fromList(utf8.encode(encodeBackupJson(children))),
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('バックアップを保存しました。機種変更時はこのファイルを新しい端末に移して読み込んでください'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('バックアップの保存に失敗しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// バックアップファイルを選んで全データを復元する。
  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    const typeGroup = XTypeGroup(
      label: 'バックアップ',
      extensions: ['json'],
    );
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [typeGroup]);
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ファイルを開けませんでした'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (file == null) return; // キャンセル

    final List<ChildProfile> restored;
    try {
      restored = decodeBackupJson(await file.readAsString());
    } on BackupDecodeException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!context.mounted) return;
    final names = restored.map((c) => c.displayName).join('・');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'バックアップを読み込む',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '現在のデータ（${children.length}名）を、バックアップの内容'
          '（${restored.length}名：$names）で置き換えます。\n\n'
          'いまのデータは失われます。よろしいですか？',
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('置き換える'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    onRestoreChildren(restored);
    messenger.showSnackBar(
      SnackBar(
        content: Text('バックアップを読み込みました（${restored.length}名）'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// 見出しの横に i マークを置き、タップで使い方の説明を出す版。
  Widget _sectionHeaderWithInfo(
    BuildContext context,
    String title, {
    required VoidCallback onInfo,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onInfo,
            icon: Icon(Icons.info_outline, size: 17, color: Colors.grey[500]),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            tooltip: 'バックアップのつかいかた',
          ),
        ],
      ),
    );
  }

  /// バックアップの仕組み（保存先・保管・機種変更の手順）の説明ダイアログ。
  void _showBackupHowTo(BuildContext context) {
    Widget step(String no, String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                no,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'バックアップのつかいかた',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step(
                '1',
                '書き出す',
                '「バックアップを書き出す」を押すと、全データが入った1つの'
                    'ファイル（.json）が端末に保存されます。\n'
                    '保存先の目安：iPhoneは「ファイル」アプリの“ダウンロード”、'
                    'Androidは“ダウンロード”フォルダです。',
              ),
              step(
                '2',
                '安全な場所に保管する',
                '書き出したファイルを、iCloud Drive・Googleドライブなどの'
                    'クラウドや、自分宛てのメールに送って保管しておくと、'
                    '端末の故障や紛失にも備えられます。',
              ),
              step(
                '3',
                '機種変更したら読み込む',
                '新しい端末にファイルを移してこのアプリを開き、'
                    '「バックアップを読み込む」でそのファイルを選ぶと、'
                    '記録がまるごと復元されます。',
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '注意：読み込むと、いまのデータはファイルの内容で置き換えられます。'
                  '記録を増やしたら、ときどき書き出し直すのがおすすめです。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Color(0xFF8A5A00),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, List<Widget> tiles) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// Pro版（オンライン自動バックアップ・広告非表示）のセクション。
///
/// 課金（ストア内購入）導入までは、Proの有効化スイッチを
/// 動作確認用として直接置いている。導入後は購入・復元ボタンに差し替える。
class _ProSection extends StatelessWidget {
  const _ProSection({
    required this.childrenData,
    required this.onRestoreChildren,
  });

  final List<ChildProfile> childrenData;
  final ValueChanged<List<ChildProfile>> onRestoreChildren;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ValueListenableBuilder<bool>(
        valueListenable: ProStatus.isPro,
        builder: (context, isPro, _) => Column(
          children: [
            // 課金導入までの動作確認用スイッチ。
            SwitchListTile(
              secondary: const Icon(
                Icons.workspace_premium_outlined,
                color: Color(0xFFB8860B),
              ),
              title: const Text(
                'Pro版',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'オンライン自動バックアップ＋広告非表示\n'
                '（課金導入前の動作確認用スイッチです）',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
              ),
              value: isPro,
              onChanged: (v) => ProStatus.setActive(v),
            ),
            if (isPro) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ValueListenableBuilder<User?>(
                valueListenable: CloudBackup.instance.user,
                builder: (context, user, _) {
                  if (user == null) {
                    return ListTile(
                      leading: Icon(Icons.login_rounded, color: scheme.primary),
                      title: const Text(
                        'サインイン',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'バックアップの保存先になるアカウントです',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showAccountSignInSheet(context),
                    );
                  }
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.account_circle_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(
                          user.email ?? 'サインイン済み',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'タップでサインアウト',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () => _confirmSignOut(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: CloudBackup.instance.autoBackupEnabled,
                        builder: (context, auto, _) => SwitchListTile(
                          secondary: Icon(
                            Icons.cloud_sync_outlined,
                            color: scheme.primary,
                          ),
                          title: const Text(
                            '自動バックアップ',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '記録を変更するたびに自動でクラウドへ保存します',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey[600],
                            ),
                          ),
                          value: auto,
                          onChanged: (v) =>
                              CloudBackup.instance.setAutoBackupEnabled(v),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: CloudBackup.instance.busy,
                        builder: (context, busy, _) =>
                            ValueListenableBuilder<DateTime?>(
                              valueListenable: CloudBackup.instance.lastBackupAt,
                              builder: (context, last, _) => ListTile(
                                leading: busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Icon(
                                        Icons.cloud_upload_outlined,
                                        color: scheme.primary,
                                      ),
                                title: const Text(
                                  '今すぐバックアップ',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  last == null
                                      ? 'まだクラウドに保存されていません'
                                      : '最終バックアップ：'
                                            '${DateFormat('yyyy/MM/dd HH:mm').format(last)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                onTap: busy ? null : () => _backupNow(context),
                              ),
                            ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(
                          Icons.cloud_download_outlined,
                          color: scheme.primary,
                        ),
                        title: const Text(
                          'クラウドから復元',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '機種変更後などに、クラウドのバックアップを読み込みます',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () => _restoreFromCloud(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await CloudBackup.instance.backupNow(childrenData);
    messenger.showSnackBar(
      SnackBar(
        content: Text(err ?? 'クラウドへバックアップしました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'サインアウト',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'サインアウトすると自動バックアップが止まります。\n'
          '端末内の記録データはそのまま残ります。',
          style: TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('サインアウト'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CloudBackup.instance.signOut();
    }
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigatorContext = context;

    final CloudBackupInfo? info;
    try {
      info = await CloudBackup.instance.fetchInfo();
    } catch (_) {
      _snackWith(messenger, 'クラウドに接続できませんでした');
      return;
    }
    if (info == null) {
      _snackWith(messenger, 'クラウドにバックアップが見つかりませんでした');
      return;
    }

    if (!navigatorContext.mounted) return;
    final dateText = info.exportedAt == null
        ? '日時不明'
        : DateFormat('yyyy/MM/dd HH:mm').format(info.exportedAt!);
    final ok = await showDialog<bool>(
      context: navigatorContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'クラウドから復元',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'クラウドのバックアップ（$dateText 保存・'
          '${info!.childNames.join('・')}）で、いまの端末のデータ'
          '（${childrenData.length}名）を置き換えます。\n\n'
          'いまのデータは失われます。よろしいですか？',
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('置き換える'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final List<ChildProfile> restored;
    try {
      restored = await CloudBackup.instance.fetchChildren();
    } on BackupDecodeException catch (e) {
      _snackWith(messenger, e.message);
      return;
    } catch (_) {
      _snackWith(messenger, 'クラウドからの読み込みに失敗しました');
      return;
    }
    onRestoreChildren(restored);
    _snackWith(messenger, 'クラウドから復元しました（${restored.length}名）');
  }

  static void _snackWith(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

/// 「お子様の管理」ページ。
///
/// プッシュ先のページは AppShell の再ビルドの影響を受けないため、
/// 一覧をローカル状態として持ち、追加・編集をローカルに反映しつつ
/// 親（AppShell）のコールバックにも伝えて永続化する。
class _ChildrenManagePage extends StatefulWidget {
  const _ChildrenManagePage({
    required this.initialChildren,
    required this.onUpdateChild,
    required this.onAddChild,
  });

  final List<ChildProfile> initialChildren;
  final void Function(int index, ChildProfile updated) onUpdateChild;
  final ValueChanged<ChildProfile> onAddChild;

  @override
  State<_ChildrenManagePage> createState() => _ChildrenManagePageState();
}

class _ChildrenManagePageState extends State<_ChildrenManagePage> {
  late final List<ChildProfile> _children = [...widget.initialChildren];

  void _update(int index, ChildProfile updated) {
    setState(() => _children[index] = updated);
    widget.onUpdateChild(index, updated);
  }

  void _add(ChildProfile child) {
    setState(() => _children.add(child));
    widget.onAddChild(child);
  }

  @override
  Widget build(BuildContext context) {
    return ChildrenScreen(
      children: _children,
      onUpdateChild: _update,
      onAddChild: _add,
    );
  }
}
