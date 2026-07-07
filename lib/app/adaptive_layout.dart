/// 大画面対応の共通レイアウト定数・ヘルパー。
library;

/// 全画面共通のコンテンツ最大幅（論理px）。
///
/// グラフ・履歴・設定・洋服ガイドすべてこの幅で頭打ちにし、
/// 画面ごとに端の位置がずれないよう統一する。超えたぶんは中央寄せ。
const double kContentMaxWidth = 600;

/// 画面幅に応じた UI クローム（下部メニュー等）の拡大率。
///
/// スマホ幅（〜480px）では 1.0、大画面では最大 1.3 倍まで比例拡大する。
double uiScaleForWidth(double screenWidth) =>
    (screenWidth / 480).clamp(1.0, 1.3);
