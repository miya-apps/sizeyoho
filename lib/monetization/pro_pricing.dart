/// Pro版の価格（表示用）。
///
/// ここの値は「アプリ内の案内表示」にのみ使う暫定値。
/// 実際の請求額は App Store / Google Play の商品設定が正であり、
/// ストア課金（in_app_purchase）導入後は、ストアから取得した
/// ローカライズ済み価格文字列に置き換えること。
/// 価格を変更したいときは、まずストアコンソール側を変更し、
/// このファイルの定数を合わせて更新する。
library;

/// 月額プランの価格（円・税込）。
const int kProMonthlyPriceYen = 300;

/// 年額プランの価格（円・税込）。
const int kProYearlyPriceYen = 2800;

/// 「¥980」のような3桁区切りの表示文字列にする。
String _yen(int amount) {
  final s = amount.toString();
  final buf = StringBuffer('¥');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 月額プランの表示価格（例：¥100）。
String get proMonthlyPriceLabel => _yen(kProMonthlyPriceYen);

/// 年額プランの表示価格（例：¥980）。
String get proYearlyPriceLabel => _yen(kProYearlyPriceYen);

/// 年額プランを月あたりに換算した表示（例：月あたり¥81）。
String get proYearlyPerMonthLabel => '月あたり${_yen(kProYearlyPriceYen ~/ 12)}';

/// 年額プランの割引率（月額×12との比較・％切り捨て）。
int get proYearlyDiscountPercent =>
    100 - (kProYearlyPriceYen * 100 ~/ (kProMonthlyPriceYen * 12));
