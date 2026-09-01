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
  static const String _establishedAt = '2026年7月7日';
  static const String _revisedAt = '2026年9月1日';

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
                        'Pro版で利用者がオンラインバックアップ（自動または'
                        '「今すぐバックアップ」）を実行した場合に限り、バックアップと'
                        '復元のために、記録データを'
                        '暗号化された通信でクラウドサーバー（Google LLC が提供'
                        'する Firebase）へ送信・保存します。この目的以外に'
                        '記録データを利用することはありません。オンラインバックアップを'
                        '実行しない場合、運営者やFirebaseへ記録データを送信しません。'
                        'ただし、利用者がファイルへの手動バックアップ、'
                        '画像・PDFの保存や共有を選んだ場合は、iCloud Driveなど利用者が'
                        '選んだ保存先・共有先へ転送されます。\n\n'
                        'なお、写真（お子様のアイコン写真・お誕生日の思い出'
                        '写真）はオンラインバックアップを利用していても'
                        'Firebaseへ送信されません。利用者が写真を含む手動バックアップ'
                        'または保存・共有を選んだ場合だけ、その選択先へ転送されます。',
                        style: _bodyStyle,
                      ),
                      _sub('（2）アカウント情報'),
                      Text(
                        'オンラインバックアップの利用時に、サインインした'
                        'アカウントのメールアドレスとユーザーIDを取得します。'
                        'これはバックアップデータの持ち主を識別するためにのみ'
                        '利用します。',
                        style: _bodyStyle,
                      ),
                      _sub('（3）広告・利用状況に関する情報（無料版）'),
                      Text(
                        '無料版では、アプリ運営のために広告を表示します。'
                        '広告の配信にあたり、広告配信事業者（Google AdMob）が'
                        'IPアドレスから推定されるおおよその地域、端末・広告に'
                        '関する識別子、広告の表示・操作、アプリの操作、クラッシュ、'
                        '性能・診断情報を取得する場合があります。これらは広告の'
                        '配信・効果測定・不正防止・サービス改善のために利用されます。\n\n'
                        'iOS版は、他社のアプリやWebサイトを横断する追跡の許可'
                        '（ATT）を要求せず、IDFAを利用しない構成です。対象地域では'
                        'Googleの同意画面を表示し、必要な場合は設定画面から同意内容を'
                        '確認・変更できます。お子様の記録データが広告事業者へ渡る'
                        'ことはありません。',
                        style: _bodyStyle,
                      ),
                      _sub('（4）購入情報'),
                      Text(
                        'Pro版の購入手続きは App Store・Google Play が'
                        '処理します。開発者がクレジットカード番号などの'
                        '決済情報を取得することはありません。',
                        style: _bodyStyle,
                      ),
                      _section('2. 第三者への提供'),
                      Text(
                        '法令に基づく場合を除き、取得した情報を第三者に'
                        '提供することはありません。上記の目的の範囲で、'
                        'Google LLC のサービス（Firebase・AdMob）を利用します。'
                        '運営者は、委託先・外部サービス提供者について、本ポリシー'
                        'と同等または同等以上の水準で情報を保護するための契約・'
                        '安全管理措置を備えたサービスを選定します。\n\n'
                        'お問い合わせには Google LLC の Googleフォームを'
                        '利用します。フォームに入力いただいた内容は、'
                        'お問い合わせへの対応目的でのみ利用します。',
                        style: _bodyStyle,
                      ),
                      _section('3. データの保管と削除'),
                      Text(
                        '端末内の記録データは、本アプリを削除すると消去されます。'
                        'クラウドから復元する対象は、最後に完全保存できた世代です。'
                        '通信途中の新旧データ混在を防ぐため、過去の技術的な保存世代や'
                        '未完了断片がFirebase内に併存する場合があり、バックアップ用'
                        'アカウントを削除するまで保管されます。iOS版でApple IDに'
                        'サインイン中は、'
                        '設定の「クラウドアカウントを削除」から、クラウド上の'
                        'バックアップとバックアップ用アカウントをアプリ内で削除でき、'
                        'Appleの認証トークンも失効させます。削除後は、別端末からの'
                        '遅延送信を拒否するため、子どもの記録やメールアドレスを含まない'
                        '最小限の削除済みマーカー（FirebaseユーザーIDと削除日時）だけを'
                        'セキュリティ目的で保持します。Googleアカウントを使用して'
                        'いる場合は、お問い合わせフォームから削除を依頼できます。\n\n'
                        'アカウント削除後も端末内の記録と写真は残るため、不要な場合は'
                        'アプリの削除または各記録の削除を行ってください。操作できない'
                        '場合はお問い合わせフォームからご連絡ください。お問い合わせ'
                        '内容は対応と法令上必要な期間に限って保管し、不要になった後に'
                        '削除します。広告関連データの保管期間はGoogleのポリシーに従い、'
                        '対象地域では設定の「広告のプライバシー設定」から同意内容を'
                        '変更できます。',
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
                        '下のボタンからお問い合わせページを開いて'
                        'ご連絡ください。',
                        style: _bodyStyle,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => openContactForm(context),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('お問い合わせページを開く'),
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
                        '制定日：$_establishedAt\n'
                        '最終改定日：$_revisedAt\n'
                        'MIYA APPS（$kAppName 運営者）',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.grey[700],
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
