import 'package:flutter/material.dart';

/// 洋服ガイド・おむつガイドで共通の「現在の値＋成長トレンド」サマリーカード。
///
/// スタイル定義を1か所にまとめることで、片方だけ直して見た目がずれる
/// （§変更依頼2-8）ことを防ぐ。値の意味（身長／体重）は呼び出し側が決める。
/// 「成長トレンド」の意味は「(直近平均)」という文言ではなく、ラベル右上の
/// ？アイコンから開くモーダルで説明する（ユーザーフィードバックにより変更）。
class GuideSummaryCard extends StatelessWidget {
  const GuideSummaryCard({
    super.key,
    required this.primaryLabel,
    required this.primaryValue,
    required this.trendLabel,
    required this.trendValue,
    this.showTrendHelp = true,
  });

  final String primaryLabel;
  final String primaryValue;
  final String trendLabel;
  final String trendValue;

  /// 成長トレンドの「？」ヘルプアイコンを出すか。タップできない書き出し
  /// 画像（画像保存）では false にして紛らわしいアイコンを消す。
  final bool showTrendHelp;

  static const Color _titleColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GuideSummaryMetric(label: primaryLabel, value: primaryValue),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _GuideSummaryMetric(
              label: trendLabel,
              value: trendValue,
              onHelpTap: showTrendHelp ? () => _showTrendHelp(context) : null,
            ),
          ),
        ],
      ),
    );
  }

  static void _showTrendHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成長トレンドとは'),
        content: const Text(
          '直近半年以内の記録（最大3件）から算出したSDスコアを平均した値です。\n\n'
          '0に近いほど、その月齢の平均的な成長曲線に近いことを、＋なら'
          '平均より大きめ、－なら平均より小さめの傾向にあることを示す'
          '目安です。サイズの予測は、この値を基準に計算しています。',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _GuideSummaryMetric extends StatelessWidget {
  const _GuideSummaryMetric({
    required this.label,
    required this.value,
    this.onHelpTap,
  });

  final String label;
  final String value;
  final VoidCallback? onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              if (onHelpTap != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onHelpTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 4, 4),
                    child: Icon(
                      Icons.help_outline,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          _buildValue(value),
        ],
      ),
    );
  }

  static const _valueStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: GuideSummaryCard._titleColor,
    height: 1.2,
  );

  /// 先頭が「+」「-」の符号付き数値は、符号の文字幅が異なる（多くのフォントで
  /// 「+」の方が「-」より幅がある）ため、符号だけ固定幅の枠に入れて、数字の
  /// 開始位置が符号によってガタつかないようにする。
  Widget _buildValue(String value) {
    final hasSign = value.startsWith('+') || value.startsWith('-');
    if (!hasSign) {
      return Text(value, style: _valueStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 11,
          child: Text(value.substring(0, 1), style: _valueStyle),
        ),
        Text(value.substring(1), style: _valueStyle),
      ],
    );
  }
}
