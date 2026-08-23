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
                      '「学校保健統計調査」（いずれも2000年度）をもとに、'
                      '日本小児内分泌学会が公開している標準値を使用しています。\n\n'
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
                  title: 'おむつサイズの目安',
                  body:
                      '各メーカーが公式サイトなどで公表している対応体重'
                      '（◯〜◯kg）のデータをもとに、記録した体重から目安の'
                      'サイズを判定しています。隣り合うサイズの対応体重が'
                      '重なる範囲は「サイズの変わり目」として両方を表示します。\n\n'
                      '公表データは製品の改良などで変更される場合があるほか、'
                      '同じ体重でも体型や製品によってフィット感は異なります。'
                      '実際のサイズ選びの参考情報としてご利用ください。',
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
                      'には利用しません。写真（アイコン・お誕生日の思い出）は'
                      'クラウドへ送信されず、端末内にのみ保存されます。写真も'
                      '引き継ぎたい場合は「バックアップを書き出す」の'
                      'ファイルをご利用ください。\n\n'
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
                      '本アプリの情報や予測は、判断材料の一つとしてご利用'
                      'ください。本アプリの利用に関する運営者の責任は、'
                      '適用される法令に従います。運営者の故意または重大な'
                      '過失による責任など、法令上免除できない責任を免れる'
                      'ものではありません。',
                ),
              ]),
              const SizedBox(height: 16),
              _card(context, const [
                _AboutItem(
                  title: 'オープンソース素材のライセンス',
                  body:
                      '本アプリでは、おむつガイドのバッジアイコンに次の'
                      'オープンソース素材を使用しています。\n\n'
                      '● Tabler Icons（MIT License）\n'
                      'おむつ・月と星・トイレットペーパー・時計のアイコン。\n'
                      'Copyright (c) 2020-2026 Paweł Kuna\n'
                      'https://tabler.io/icons\n\n'
                      'Permission is hereby granted, free of charge, to any '
                      'person obtaining a copy of this software and associated '
                      'documentation files (the "Software"), to deal in the '
                      'Software without restriction, including without '
                      'limitation the rights to use, copy, modify, merge, '
                      'publish, distribute, sublicense, and/or sell copies of '
                      'the Software, and to permit persons to whom the '
                      'Software is furnished to do so, subject to the '
                      'following conditions: The above copyright notice and '
                      'this permission notice shall be included in all copies '
                      'or substantial portions of the Software. '
                      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF '
                      'ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED '
                      'TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A '
                      'PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT '
                      'SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR '
                      'ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN '
                      'ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
                      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE '
                      'OR OTHER DEALINGS IN THE SOFTWARE.\n\n'
                      '● Lucide Icons（ISC License）\n'
                      '状態バッジ（サイズUP・サイズ上限・超過）のアイコン。\n'
                      'https://github.com/lucide-icons/lucide\n\n'
                      'Permission to use, copy, modify, and/or distribute '
                      'this software for any purpose with or without fee is '
                      'hereby granted, provided that the above copyright '
                      'notice and this permission notice appear in all '
                      'copies.\n\n'
                      '● Streamline Icons（CC BY 4.0）\n'
                      '水遊び用バッジのアイコン（Covid Icons セットの '
                      'Vaccine Protection Infrared Thermometer Gun）。\n'
                      'https://streamlinehq.com\n\n'
                      'Creative Commons Attribution 4.0 International'
                      '（CC BY 4.0）のもとで利用しています。\n'
                      'https://creativecommons.org/licenses/by/4.0/',
                ),
              ]),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '$kAppName バージョン $kAppVersion',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          color: Colors.grey[700],
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
