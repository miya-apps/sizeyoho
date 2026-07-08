import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';
import '../app/app_info.dart';
import '../support/contact_launcher.dart';

/// プライバシーポリシー画面（設定 → このアプリについて から開く）。
///
/// ストア公開時には同じ内容を公開URL（Webページ）にも掲載する。
/// 内容を変更したら [_revisedAt] を更新すること。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _background = Color(0xFFF6F6F8);
  static const String _revisedAt = '2026年7月8日';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'プライバシーポリシー',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '「$kAppName」（以下「本アプリ」）は、利用者の'
                        'プライバシーを尊重し、個人情報を次のとおり'
                        '取り扱います。',
                        style: _bodyStyle,
                      ),
                      _section('1. 取得する情報と利用目的'),
                      _sub('（1）記録データ'),
                      Text(
                        'お子様のお名前（ニックネームでも構いません）・'
                        '生年月日・性別・身長・体重・足長・写真・メモなど、'
                        '利用者が入力した記録は、お使いの端末内に保存されます。\n\n'
                        'Pro版の「オンライン自動バックアップ」をオンにした'
                        '場合に限り、バックアップと復元のために、記録データを'
                        '暗号化された通信でクラウドサーバー（Google LLC が提供'
                        'する Firebase）へ送信・保存します。この目的以外に'
                        '記録データを利用することはありません。オンライン自動'
                        'バックアップを使わない場合、記録データが端末の外へ'
                        '送信されることはありません。',
                        style: _bodyStyle,
                      ),
                      _sub('（2）アカウント情報'),
                      Text(
                        'オンライン自動バックアップの利用時に、サインインした'
                        'アカウントのメールアドレスとユーザーIDを取得します。'
                        'これはバックアップデータの持ち主を識別するためにのみ'
                        '利用します。',
                        style: _bodyStyle,
                      ),
                      _sub('（3）広告用の識別子（無料版）'),
                      Text(
                        '無料版では、アプリ運営のために広告を表示します。'
                        '広告の配信にあたり、広告配信事業者（Google AdMob）が'
                        '広告用の識別子などの情報を取得する場合があります。'
                        'お子様の記録データが広告事業者へ渡ることはありません。',
                        style: _bodyStyle,
                      ),
                      _sub('（4）購入情報'),
                      Text(
                        'Pro版の購入手続きは App Store / Google Play が'
                        '処理します。開発者がクレジットカード番号などの'
                        '決済情報を取得することはありません。',
                        style: _bodyStyle,
                      ),
                      _section('2. 第三者への提供'),
                      Text(
                        '法令に基づく場合を除き、取得した情報を第三者に'
                        '提供することはありません。上記の目的の範囲で、'
                        'Google LLC のサービス（Firebase・AdMob）を利用します。\n\n'
                        'お問い合わせには Google LLC の Googleフォームを'
                        '利用します。フォームに入力いただいた内容は、'
                        'お問い合わせへの対応目的でのみ利用します。',
                        style: _bodyStyle,
                      ),
                      _section('3. データの保管と削除'),
                      Text(
                        '端末内の記録データは、本アプリを削除すると消去されます。'
                        'クラウド上のバックアップは常に最新の内容で上書き保存'
                        'されます。クラウド上のバックアップの削除をご希望の'
                        '場合は、お問い合わせフォームで「個人情報・データ削除」'
                        'を選び、サインインに使用したアカウントを記載のうえ'
                        'ご連絡ください。本人確認のうえ削除します。',
                        style: _bodyStyle,
                      ),
                      _section('4. お子様の情報について'),
                      Text(
                        '本アプリは、保護者の方がお子様の成長を記録・管理する'
                        'ためのものです。記録データの入力と管理は保護者の'
                        '責任で行ってください。',
                        style: _bodyStyle,
                      ),
                      _section('5. 改定について'),
                      Text(
                        '本ポリシーの内容を変更する場合は、アプリ内で'
                        'お知らせします。',
                        style: _bodyStyle,
                      ),
                      _section('6. お問い合わせ'),
                      Text(
                        'ご意見・不具合のご報告・データ削除のご依頼などは、'
                        '下のボタンからお問い合わせフォームを開いて'
                        'ご連絡ください。',
                        style: _bodyStyle,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => openContactForm(context),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('お問い合わせフォームを開く'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '制定日：$_revisedAt\nMIYA APPS（$kAppName 運営者）',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.grey[600],
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
    );
  }

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.7,
    color: Color(0xFF555555),
  );

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _sub(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF444444),
        ),
      ),
    );
  }
}
