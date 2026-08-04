import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../growth/clothing_size_guide.dart';
import 'footprint_icon.dart';

/// 靴ガイドの「いま → 次の購入 → その先」ステップ表示。
///
/// 画面（靴ガイド）と書き出し画像（サイズガイドの正方形画像）の両方で
/// 同じ見た目・同じ流れになるよう、部品をここに一本化している。
///
/// 構成のルール（ユーザーフィードバックによる整理）：
/// - サイズアウト時の警告は「いま」行の上のバナーに出す
/// - 「いま」行は常にいまの目安サイズ。サイズアウト時はこれが
///   そのまま買い替えおすすめのサイズになる（同じ数字を2回出さない）
/// - その下に「次の購入」「その先」の先読み行（Pro版の内容）が続く

/// サイズアウト警告などに使う注意色（靴ガイド画面の _staleColor と同じ）。
const Color kShoeWarnColor = Color(0xFFB25E09);

const Color _titleColor = Color(0xFF1A1A1A);

/// 予測時期の表示（例：2027年5月頃）。
String formatShoeMonthLabel(DateTime d) => '${d.year}年${d.month}月頃';

/// 「実測足長 → いまの目安 ｜ いまの靴」の数値サマリーカード。
///
/// 予測の出発点（実測値）から目安が導かれる流れを、アイコンと矢印で
/// 直感的に示す（実測=足あと、目安=買い物、いまの靴=スニーカー）。
/// 画面（靴ガイド）と書き出し画像の両方で同じものを使う。
class ShoeMetricsCard extends StatelessWidget {
  const ShoeMetricsCard({super.key, required this.plan});

  final ShoeSizePurchasePlan plan;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final lastPurchase = plan.lastPurchase;
    final measured = plan.measuredAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              icon: const FootprintIcon(size: 14),
              label: '実測足長',
              value: '${plan.measuredFootLengthCm.toStringAsFixed(1)}cm',
              sub: '${measured.year}/${measured.month}/${measured.day} 測定',
            ),
          ),
          // 実測から目安を計算している（導出関係）ことを矢印で示す。
          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey[400]),
          Expanded(
            child: _metric(
              icon: Icon(Icons.shopping_bag_outlined, size: 14, color: accent),
              label: 'いまの目安',
              value: '${plan.currentShoeSizeCm.toStringAsFixed(1)}cm',
              sub: '予測足長 ${plan.currentFootLengthCm.toStringAsFixed(1)}cm',
            ),
          ),
          // 「いまの靴」は独立した購入記録なので、矢印ではなく仕切り線。
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: Colors.grey.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _metric(
              // おむつ/洋服/靴の切り替えセグメントと同じ線画のスニーカー。
              icon: PhosphorIcon(
                PhosphorIconsRegular.sneaker,
                size: 14,
                color: accent,
              ),
              label: 'いまの靴',
              value: lastPurchase != null
                  ? '${lastPurchase.sizeCm.toStringAsFixed(1)}cm'
                  : '—',
              sub: lastPurchase != null
                  ? '${lastPurchase.date.year}/${lastPurchase.date.month}/'
                      '${lastPurchase.date.day} 購入'
                  : '購入記録なし',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required Widget icon,
    required String label,
    required String value,
    required String sub,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _titleColor,
            height: 1.25,
          ),
        ),
        // 3列で幅が狭いため、長い補足は縮小して1行に収める。
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            sub,
            maxLines: 1,
            style: TextStyle(fontSize: 9.5, color: Colors.grey[500], height: 1.2),
          ),
        ),
      ],
    );
  }
}

/// サイズアウト警告バナー。「いま」行の上に置く。
class ShoeOutgrownBanner extends StatelessWidget {
  const ShoeOutgrownBanner({super.key, this.lastPurchaseSizeCm});

  /// いまの靴のサイズ（購入記録があれば文中に併記する）。
  final double? lastPurchaseSizeCm;

  @override
  Widget build(BuildContext context) {
    final size = lastPurchaseSizeCm;
    final text = size != null
        ? 'いまの靴（${size.toStringAsFixed(1)}cm）が小さくなっている可能性があります'
        : 'いまの靴が小さくなっている可能性があります';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: kShoeWarnColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kShoeWarnColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.priority_high_rounded, size: 18, color: kShoeWarnColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: kShoeWarnColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「📍いま」バッジ付きの先頭行。いま買うならこのサイズ、という
/// おすすめを示す（「いま」はバッジに任せ、ラベルは「おすすめ」にして
/// 言葉の重複を避ける）。サイズアウト時は注記が買い替えの促しになる。
class ShoeCurrentStepRow extends StatelessWidget {
  const ShoeCurrentStepRow({super.key, required this.plan});

  final ShoeSizePurchasePlan plan;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final outgrown = plan.currentShoeOutgrown;
    return ShoeStepRow(
      accent: accent,
      // おむつ/洋服/靴の切り替えセグメントと同じ線画のスニーカー。
      icon: PhosphorIcon(PhosphorIconsRegular.sneaker, size: 20, color: accent),
      label: 'おすすめ',
      sizeText: '${plan.currentShoeSizeCm.toStringAsFixed(1)}cm',
      note: outgrown ? '早めの買い替えを' : 'ちょうどよい目安',
      noteColor: outgrown ? kShoeWarnColor : null,
      isCurrent: true,
    );
  }
}

/// 「いま」行の下に続く先読み行（Pro版の内容）。
///
/// - 通常時：↓ 次の購入（○月頃） ＋ あれば ↓ その先（○月頃）
/// - サイズアウト時：↓ その先（いま買うサイズの次に上がるサイズ）
/// - 当面サイズアップが無い場合：案内の1行
class ShoeForecastStepRows extends StatelessWidget {
  const ShoeForecastStepRows({super.key, required this.plan});

  final ShoeSizePurchasePlan plan;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final children = <Widget>[];

    if (plan.currentShoeOutgrown) {
      // 「いま」行がそのまま買い替えおすすめなので、次に上がるサイズだけ示す。
      final later = plan.upcoming.isNotEmpty ? plan.upcoming.first : null;
      if (later != null) {
        children
          ..add(_arrow(accent))
          ..add(ShoeStepRow(
            accent: accent,
            icon: Icon(Icons.schedule_rounded, size: 20, color: accent),
            label: 'その先',
            sizeText: '${later.shoeSizeCm.toStringAsFixed(1)}cm',
            note: formatShoeMonthLabel(later.approxDate),
          ));
      }
    } else {
      final next = plan.nextPurchase;
      if (next == null) {
        children
          ..add(_arrow(accent))
          ..add(const ShoeStepInfoRow(text: '当面はサイズアップの予定はありません'));
      } else {
        children
          ..add(_arrow(accent))
          ..add(ShoeStepRow(
            accent: accent,
            icon: Icon(Icons.shopping_bag_outlined, size: 20, color: accent),
            label: '次の購入',
            sizeText: '${next.shoeSizeCm.toStringAsFixed(1)}cm',
            note: '${formatShoeMonthLabel(next.approxDate)} 購入おすすめ',
          ));
        final later = plan.upcoming.length > 1 ? plan.upcoming[1] : null;
        if (later != null) {
          children
            ..add(_arrow(accent))
            ..add(ShoeStepRow(
              accent: accent,
              icon: Icon(Icons.schedule_rounded, size: 20, color: accent),
              label: 'その先',
              sizeText: '${later.shoeSizeCm.toStringAsFixed(1)}cm',
              note: formatShoeMonthLabel(later.approxDate),
            ));
        }
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _arrow(Color accent) => Icon(
        Icons.keyboard_double_arrow_down_rounded,
        size: 16,
        color: accent.withValues(alpha: 0.65),
      );
}

/// 1ステップぶんの行（アイコン｜ラベル｜サイズ｜補足）。
/// 洋服ガイドの季節行と同じ視覚言語。
class ShoeStepRow extends StatelessWidget {
  const ShoeStepRow({
    super.key,
    required this.accent,
    required this.icon,
    required this.label,
    required this.sizeText,
    this.note,
    this.noteColor,
    this.isCurrent = false,
  });

  final Color accent;
  final Widget icon;
  final String label;
  final String sizeText;
  final String? note;
  final Color? noteColor;

  /// 「📍いま」バッジを付けるか（洋服の「📍今シーズン」と同じ見た目）。
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    // テーマ色そのままに近いと淡色テーマで読みにくいため、黒に寄せる。
    final labelColor = Color.lerp(accent, Colors.black, 0.55)!;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 7),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ),
          Text(
            sizeText,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          if (note != null)
            // 幅が足りないときは、はみ出さず縮小して右寄せで収める。
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      note!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: noteColor ?? Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!isCurrent) return row;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 5), child: row),
        Positioned(
          top: 0,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFE65100).withValues(alpha: 0.30),
              ),
            ),
            child: const Text(
              '📍いま',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE65100),
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ステップ列の中に置く案内の1行（例：当面サイズアップなし）。
class ShoeStepInfoRow extends StatelessWidget {
  const ShoeStepInfoRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
