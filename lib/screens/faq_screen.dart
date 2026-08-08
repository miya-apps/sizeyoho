import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';

/// Q&A・用語解説画面。
/// SD スコアなどの用語と、成長ペース・洋服ガイドの計算ロジックを
/// 保護者向けのことばで説明する（設定画面から開く）。
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const Color _background = Color(0xFFF6F6F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Q&A・用語解説',
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
              _sectionHeader(context, '用語解説'),
              _faqCard(context, [
                const _FaqItem(
                  question: 'SDスコアとは？',
                  answer:
                      '同じ性別・同じ月齢の子どもたちの平均と比べて、身長や体重が'
                      'どのくらいの位置にあるかを表した数値です。\n\n'
                      '0が平均で、＋なら平均より大きめ、−なら小さめを意味します。'
                      '＋2.0や−2.0は「平均からかなり離れている」目安です。\n\n'
                      'このアプリでは、厚生労働省・文部科学省の2000年度調査に'
                      '基づく基準値（LMS法）を使って計算しています。',
                ),
                const _FaqItem(
                  question: '標準範囲（±2SD）とは？',
                  answer:
                      'SDスコアが−2.0〜＋2.0の範囲のことで、同じ月齢の子どもの'
                      '約95%がこの中に入ります。\n\n'
                      '範囲を外れていても、すぐに異常というわけではありません。'
                      '大切なのは「自分のカーブに沿って伸びているか」です。'
                      '気になる場合は、乳幼児健診やかかりつけの小児科で'
                      'グラフを見せながら相談してみてください（PDF出力が便利です）。',
                ),
                const _FaqItem(
                  question: '修正月齢とは？',
                  answer:
                      '予定日より早く生まれたお子様の発育を見るときに、'
                      '出産予定日を基準にして数え直した月齢です。\n\n'
                      '例えば2ヶ月早く生まれた場合、生後6ヶ月の時点の修正月齢は'
                      '4ヶ月になります。お子様の設定で出産予定日を登録すると、'
                      'グラフを修正月齢表示に切り替えられます。',
                ),
                const _FaqItem(
                  question: '成長曲線のもとになっているデータは？',
                  answer:
                      '厚生労働省「乳幼児身体発育調査」と文部科学省「学校保健統計'
                      '調査」（いずれも2000年度）をもとにした、日本小児内分泌学会'
                      '推奨の基準値を使用しています。母子手帳の成長曲線と同じ'
                      '系統のデータです。',
                ),
              ]),
              const SizedBox(height: 16),
              _sectionHeader(context, '機能の仕組み'),
              _faqCard(context, [
                const _FaqItem(
                  question: '成長ペースはどう計算している？',
                  answer:
                      '最新の身長記録を基準にして、選んだ期間だけさかのぼった記録'
                      '（直近1年なら約365日前に最も近い記録）と比較しています。\n\n'
                      '表示されるのは、その間に伸びた高さ（cm）、1年あたりに'
                      '換算した伸びのペース（cm/年）、期間の前後でのSDスコアの'
                      '変化です。記録一覧から任意の2つの記録を選んで比較する'
                      'こともできます。',
                ),
                const _FaqItem(
                  question: '洋服ガイドのサイズ予測はどう計算している？',
                  answer:
                      '最新の測定日から半年以内の身長記録（最大3件）のSDスコアを'
                      '平均し、それを「いまの成長トレンド」とします。\n\n'
                      'そのトレンドのまま成長曲線に沿って伸びると仮定して、'
                      '各シーズン（春夏秋冬）の時期の身長を予測し、JIS規格を'
                      'もとにしたサイズ（80・90・100…）に当てはめています。\n\n'
                      'あくまで目安なので、実際の体格やメーカーによる違いも'
                      'あわせてご検討ください。',
                ),
                const _FaqItem(
                  question: 'おむつガイドはどこから使える？サイズはどう決まる？',
                  answer:
                      'お子様の編集画面（上部の名前をタップ → 編集）で'
                      '「おむつガイド」をONにすると、サイズ予報タブに'
                      '「おむつ」が追加されます。よく使うブランド・シリーズ・'
                      'タイプ（テープ／パンツ）はお子様ごとに登録できます。\n\n'
                      'サイズの判定は、各メーカーが公表している対応体重'
                      '（◯〜◯kg）と、記録した体重を照らし合わせて行います。'
                      '隣り合うサイズの対応体重は重なっているため、その範囲では'
                      '「サイズの変わり目」として両方のサイズを表示します。\n\n'
                      '体重の記録があると、伸びのトレンドから「次のサイズに'
                      '切り替わる時期」や「いまのサイズを使える見込み」の'
                      '目安も表示します。',
                ),
                const _FaqItem(
                  question: '靴サイズの予測はどう計算している？',
                  answer:
                      '靴ガイドで記録した足長の実測値を基準に、次の手順で'
                      '計算しています。\n\n'
                      '① 実測した足長 ÷ 実測時点の推定身長 ＝「足長の比率」。'
                      'この比率を、その子の足の大きさの個性として固定します。\n'
                      '② 成長トレンドに沿って予測した将来の身長に、①の比率を'
                      '掛けて将来の足長を予測します。\n'
                      '③ 予測足長につま先の余裕 0.7cm を足し、0.5cm 単位に'
                      '切り上げたものが靴サイズの目安です（買った時点の余裕は'
                      '0.7〜1.2cm になります）。\n'
                      '④ 1ヶ月ずつ先読みして、履いている靴のつま先の余裕が'
                      '0.5cm を切る月を「買い替えおすすめ時期」としています。\n\n'
                      '「余裕が 0.5cm まで減ったら買い替え」という考え方なので、'
                      'おすすめ通りのサイズを買った直後に次の買い替えが表示される'
                      'ことはありません。買い替えまでの間隔は一律ではなく、'
                      '身長の伸びが速い時期（乳幼児期）は短く、成長がゆるやかに'
                      'なるにつれて長くなります。\n\n'
                      '購入した靴のサイズも記録すると、その靴を基準に'
                      '「きつくなる時期」を計算するため、目安がより正確に'
                      'なります。\n\n'
                      '足の形やメーカーによる違いもあるため、数ヶ月ごとに'
                      '実測値を更新すると精度が保てます。',
                ),
                const _FaqItem(
                  question: '受診レポート（PDF）には何が含まれる？',
                  answer:
                      'グラフ画面・サイズ予報画面の左上にある「画像保存」を'
                      '開くと、いちばん下に「受診レポート（PDF）を出力」が'
                      'あります（無料版でも使えます）。お子様の情報'
                      '（生年月日・性別・ご両親の身長・目標身長など）、'
                      '成長曲線グラフ、SDスコアの推移、記録の一覧表を'
                      'A4・1枚のレポートにまとめて出力します。\n\n'
                      'グラフの範囲は、全記録が収まるように自動で選ばれます。'
                      '記録が多い場合、一覧表には直近24件を掲載します'
                      '（すべての記録の推移はグラフで確認できます）。\n\n'
                      '健診や小児科の受診時にそのまま見せられる形式なので、'
                      '印刷やメール添付でご活用ください。',
                ),
                const _FaqItem(
                  question: 'グラフやサイズガイドを画像で保存・シェアできる？',
                  answer:
                      'グラフ画面・サイズ予報画面の左上にある「画像保存」から、'
                      '成長曲線・SDスコア・おむつ・洋服・靴のガイドを、'
                      'SNSやメッセージアプリで共有しやすい正方形の画像で'
                      '保存・シェアできます（Pro版の機能）。\n\n'
                      '保存前に完成品をプレビューで確認でき、上のチップや'
                      '左右スワイプで種類を切り替えられます。背景カラーの'
                      '変更や、名前を出すかどうかの切り替えもその場で'
                      'できます。「シェア」を押すと、保存を挟まずに'
                      'そのままLINEなどの共有先へ送れます。',
                ),
                const _FaqItem(
                  question: '書き出すときに名前を伏せられる？',
                  answer:
                      '「画像保存」で開く画面の「名前を表示」をOFFにすると、'
                      '保存した画像（成長曲線・SDスコア・サイズガイド）には'
                      '名前の代わりにお子様のアイコンだけが表示されます。'
                      'アイコンに写真を設定していても、画像には写真ではなく'
                      '選択中のアイコンの絵柄を使います。\n\n'
                      'この切り替えは設定として保存され、受診レポート（PDF）と'
                      'ファイル名は「第一子」「第二子」…の表記になります。'
                      '順番は登録中のお子様の生まれた順で、双子など同日生まれの'
                      '場合は登録順です。アプリ内の表示は実名のまま変わりません。',
                ),
                const _FaqItem(
                  question: '機種変更のときはどうすればいい？（バックアップ）',
                  answer:
                      'Pro版のオンライン自動バックアップをオンにしている場合は、'
                      '新しい端末で同じアカウントにサインインするだけで記録を'
                      '復元できます。ただし写真（アイコン・お誕生日の思い出）は'
                      'クラウドに送信されないため、写真も引き継ぎたい場合は'
                      '下記の手動バックアップをあわせてご利用ください。\n\n'
                      '手動でバックアップする場合：\n'
                      '① 設定 →「バックアップを書き出す」でファイル（.json）を保存\n'
                      '　（iPhoneは「ファイル」アプリ、Androidはダウンロード'
                      'フォルダに入ります）\n'
                      '② そのファイルをクラウドやメールなどで新しい端末へ\n'
                      '③ 新しい端末で「バックアップを読み込む」からファイルを選択\n\n'
                      '端末の故障に備えて、ときどき書き出してクラウドなどに'
                      '保管しておくのもおすすめです。',
                ),
                const _FaqItem(
                  question: 'お誕生日の思い出はどこから見られる？',
                  answer:
                      '誕生月に表示されるお祝い画面のほか、次の場所からいつでも'
                      '見返したり、あとから追加・編集したりできます。\n\n'
                      '・履歴タブ左上の「思い出」ボタン（選択中のお子様の分）\n'
                      '・設定 →「お誕生日の思い出」（ご家族全員の分）\n\n'
                      '写真・サイズ・メモは年齢ごとに1件ずつ残せます。'
                      '手動の「バックアップを書き出す」のファイルには写真も'
                      '含まれますが、Pro版のクラウド自動バックアップに写真は'
                      '含まれず、お使いの端末内にのみ保存されます。',
                ),
              ]),
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

  Widget _faqCard(BuildContext context, List<_FaqItem> items) {
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

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

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
        question,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          answer,
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
