import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';
import '../app/app_info.dart';

/// 「データの根拠・免責事項」画面。
///
/// 専門家の監修を受けていないアプリだからこそ、表示している数値の
/// 根拠（もとにしている公的データ・計算方法）と、利用上の注意
/// （免責事項）を明示する。Q&A・用語解説と同じアコーディオン形式で、
/// 見出しだけを一覧できるようにしている（設定画面から開く）。
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const Color _background = Color(0xFFF6F6F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'データの根拠・免責事項',
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
              _sectionHeader(context, 'データと計算の根拠'),
              _card(context, const [
                _AboutItem(
                  title: '成長曲線・SDスコア',
                  body:
                      '厚生労働省「乳幼児身体発育調査」および文部科学省'
                      '「学校保健統計調査」（いずれも2000年度）をもとにした、'
                      '日本小児内分泌学会推奨の標準値を使用しています。'
                      '母子健康手帳の成長曲線と同じ系統の公的データです。\n\n'
                      '数値の位置づけ（SDスコア）は、国際的に用いられている'
                      'LMS法で計算しています。基準点の間の月齢は、値を'
                      '歪めない単調3次補間でなめらかにつないでいます。',
                ),
                _AboutItem(
                  title: '洋服サイズの目安',
                  body:
                      'JIS規格（こども服）の身長対応サイズ（80・90・100…）を'
                      'もとに、予測身長から「その時期にちょうど良いサイズ」を'
                      '当てはめています。',
                ),
                _AboutItem(
                  title: '靴サイズの予測',
                  body:
                      '保護者が実測した足長を基準に、身長の成長トレンドと'
                      '連動させて将来の足長を予測しています。詳しい手順は'
                      '「Q&A・用語解説」をご覧ください。',
                ),
                _AboutItem(
                  title: '修正月齢',
                  body:
                      '予定日より早く生まれたお子様について、出産予定日を'
                      '基準に数え直した月齢で発育を見る、小児保健で一般的な'
                      '考え方に沿っています。',
                ),
              ]),
              const SizedBox(height: 16),
              _sectionHeader(context, '免責事項'),
              _card(context, const [
                _AboutItem(
                  title: '本アプリは医療機器ではありません',
                  body:
                      '本アプリは保護者がお子様の成長を記録・整理するための'
                      'ツールであり、疾患の診断・治療・予防を目的とした'
                      'ものではありません。',
                ),
                _AboutItem(
                  title: '表示される数値は目安です',
                  body:
                      'グラフ・SDスコア・サイズ予測などは、統計的な基準に'
                      '基づく参考情報です。成長には個人差があり、標準範囲を'
                      '外れることがただちに異常を意味するものではありません。',
                ),
                _AboutItem(
                  title: '心配なことは専門家へ',
                  body:
                      'お子様の発育・健康について気になることがある場合は、'
                      '本アプリの表示だけで判断せず、乳幼児健診や'
                      'かかりつけの小児科医・保健師にご相談ください。'
                      '受診の際は「受診レポート」のPDF出力をご活用いただけます。',
                ),
                _AboutItem(
                  title: 'データの保存について',
                  body:
                      '記録データ（お誕生日の写真を含む）は、基本的に'
                      'お使いの端末内に保存されます。端末の故障・紛失・'
                      'アプリの削除などで消失する場合があるため、設定の'
                      '「バックアップを書き出す」で定期的に控えを残すことを'
                      'おすすめします。\n\n'
                      'Pro版のオンライン自動バックアップをオンにした場合は、'
                      '機種変更や紛失に備えて、記録データが暗号化された通信で'
                      'クラウドサーバーへ送信・保存されます。送信されるのは'
                      'バックアップに必要な記録データのみで、復元の目的以外'
                      'には利用しません。\n\n'
                      'オンライン自動バックアップを使わない場合、記録データが'
                      '端末の外へ送信されることはありません。',
                ),
                _AboutItem(
                  title: '広告について',
                  body:
                      '無料版では、アプリ運営のために広告を表示します。'
                      '広告の配信にあたり、広告配信事業者が広告用の識別子'
                      'などの情報を取得する場合があります（お子様の記録'
                      'データが広告事業者へ渡ることはありません）。'
                      'Pro版では広告は表示されません。\n\n'
                      '詳細は、設定 →「プライバシーポリシー」をご覧ください。',
                ),
                _AboutItem(
                  title: '責任の範囲',
                  body:
                      '本アプリの利用または利用できないことにより生じた'
                      'いかなる損害についても、開発者は責任を負いかねます。'
                      'あらかじめご了承ください。',
                ),
              ]),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '$kAppName バージョン $kAppVersion',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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

  Widget _card(BuildContext context, List<_AboutItem> items) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            items[i],
          ],
        ],
      ),
    );
  }
}

/// Q&A・用語解説（faq_screen.dart）と同じ見た目のアコーディオン1項目。
class _AboutItem extends StatelessWidget {
  const _AboutItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      iconColor: scheme.primary,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.7,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }
}
