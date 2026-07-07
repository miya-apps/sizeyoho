import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_info.dart';
import '../growth/clothing_size_guide.dart';
import '../models/child_profile.dart';
import '../screens/clothing_guide_screen.dart'
    show seasonAccentColor, seasonBaseColor, seasonIconData;
import '../screens/shoe_guide_screen.dart' show formatShoeMonthLabel;

/// 洋服ガイド＋靴ガイドをまとめた「1枚物のサイズガイド画像」。
///
/// 画面のスクショではなく、共有・保存専用にレイアウトした固定幅カードを
/// 画面外に一瞬だけ描画して PNG 化する（[captureSizeGuideImage]）。
/// 画面の 2×2 カードではなく、季節を時系列に並べたコンパクトな表にして、
/// 縦の余白を抑えて1枚に収める。
class SizeGuideExportCard extends StatelessWidget {
  const SizeGuideExportCard({super.key, required this.child, this.displayName});

  final ChildProfile child;

  /// タイトルに使う名前（未指定なら実名）。
  /// プライバシー設定の「第一子」などの匿名表記に使う。
  final String? displayName;

  /// 画像の基準幅（論理px）。画面表示のデザイン幅と揃える。
  static const double designWidth = 420;

  static const _titleColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final guide = ClothingSizeGuideCalculator.compute(child);
    final now = DateTime.now();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: designWidth,
        // アプリ画面と同じ「白＋テーマ淡色」の背景（透過PNGにしない）。
        color: Color.alphaBlend(
          child.themeColor.withValues(alpha: 0.10),
          Colors.white,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ヘッダー ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${displayName ?? child.displayName} のサイズ予報',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                ),
                Text(
                  '${now.year}/${now.month}/${now.day} 作成',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '直近の成長トレンドから予測した目安です',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),

            // ── 洋服 ──
            _sectionHeader(
              icon: PhosphorIconsDuotone.shirtFolded,
              label: '洋服',
              accent: scheme.primary,
              trailing: guide.hasData
                  ? '現在の身長 ${guide.currentHeightCm!.toStringAsFixed(1)}cm'
                        '${guide.baselineSdScore != null ? '・トレンド ${formatBaselineSdScore(guide.baselineSdScore!)}' : ''}'
                  : null,
            ),
            const SizedBox(height: 6),
            if (guide.hasData)
              _SeasonTable(entries: guide.timeline)
            else
              _emptyNote(guide.message ?? '身長の記録が足りません'),
            const SizedBox(height: 12),

            // ── 靴 ──
            _sectionHeader(
              icon: PhosphorIconsDuotone.sneaker,
              label: '靴',
              accent: scheme.primary,
            ),
            const SizedBox(height: 6),
            _ShoeExportSection(child: child),
            const SizedBox(height: 10),
            // ── フッター（作成アプリ名） ──
            Center(
              child: Text(
                '作成：$kAppName',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required PhosphorDuotoneIconData icon,
    required String label,
    required Color accent,
    String? trailing,
  }) {
    return Row(
      children: [
        PhosphorIcon(
          icon,
          size: 19,
          color: accent,
          duotoneSecondaryColor: accent.withValues(alpha: 0.45),
          duotoneSecondaryOpacity: 1,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyNote(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
      ),
    );
  }
}

/// 季節ごとの購入サイズを時系列（今シーズンが先頭）の行で並べた表。
/// アプリ画面と同じ「季節のベース色＋差し色」の行デザインで、
/// 行間の下向き矢印で季節の移り変わりを示す。
class _SeasonTable extends StatelessWidget {
  const _SeasonTable({required this.entries});

  final List<ClothingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 先頭行の「今シーズン」バッジが行の上枠にかかるぶんの余白。
        const SizedBox(height: 5),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 15,
              color: seasonAccentColor(entries[i].title)
                  .withValues(alpha: 0.65),
            ),
          _SeasonRow(entry: entries[i], isCurrentSeason: i == 0),
        ],
      ],
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.entry, required this.isCurrentSeason});

  final ClothingTimelineEntry entry;
  final bool isCurrentSeason;

  @override
  Widget build(BuildContext context) {
    final accent = seasonAccentColor(entry.title);
    final titleColor = Color.lerp(accent, Colors.black, 0.35)!;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: seasonBaseColor(entry.title),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            seasonIconData(entry.title),
            size: 20,
            color: accent,
            duotoneSecondaryColor: accent.withValues(alpha: 0.45),
            duotoneSecondaryOpacity: 1,
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 42,
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 今年・来年のサイズ（年ラベルで時系列が伝わるため矢印は置かない）
          Expanded(
            child: _yearSize(
              year: formatClothingTargetYearLabel(entry.targetDateThisYear),
              sizeCm: entry.thisYearJustSize,
              estimatedHeightCm: entry.thisYearEstimatedHeightCm,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _yearSize(
              year: formatClothingTargetYearLabel(entry.targetDateNextYear),
              sizeCm: entry.nextYearJustSize,
              estimatedHeightCm: entry.nextYearEstimatedHeightCm,
              highlighted: true,
              accent: accent,
            ),
          ),
        ],
      ),
    );

    if (!isCurrentSeason) return row;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        row,
        Positioned(
          top: -6,
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
              '📍今シーズン',
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

  Widget _yearSize({
    required String year,
    required int sizeCm,
    required double estimatedHeightCm,
    bool highlighted = false,
    Color? accent,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$year年',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${sizeCm}cm',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Text(
          '推定${estimatedHeightCm.toStringAsFixed(1)}cm',
          style: TextStyle(fontSize: 10, color: Colors.grey[600], height: 1.2),
        ),
      ],
    );

    if (!highlighted || accent == null) return content;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent, width: 1.3),
      ),
      child: content,
    );
  }
}

/// 靴ガイドの要約（いまの目安・いまの靴・次の購入時期）。
class _ShoeExportSection extends StatelessWidget {
  const _ShoeExportSection({required this.child});

  final ChildProfile child;

  static const _titleColor = Color(0xFF1A1A1A);
  static const _staleColor = Color(0xFFB25E09);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = computeShoeSizePurchasePlan(child);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: plan == null
          ? Text(
              '足長の記録がまだありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : _body(scheme, plan),
    );
  }

  Widget _body(ColorScheme scheme, ShoeSizePurchasePlan plan) {
    final lastPurchase = plan.lastPurchase;
    final next = plan.nextPurchase;
    final bannerColor = plan.currentShoeOutgrown ? _staleColor : scheme.primary;

    final String nextText;
    if (next == null) {
      nextText = '当面はサイズアップの予定はありません';
    } else if (plan.currentShoeOutgrown) {
      nextText = 'いまの靴が小さいかも。'
          '${next.shoeSizeCm.toStringAsFixed(1)}cm への買い替えをおすすめ';
    } else {
      nextText = '次は ${next.shoeSizeCm.toStringAsFixed(1)}cm を'
          '${formatShoeMonthLabel(next.approxDate)}に購入おすすめ';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _metric(
                'いまの目安',
                '${plan.currentShoeSizeCm.toStringAsFixed(1)}cm',
              ),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.grey.withValues(alpha: 0.15),
            ),
            Expanded(
              child: _metric(
                'いまの靴',
                lastPurchase != null
                    ? '${lastPurchase.sizeCm.toStringAsFixed(1)}cm'
                    : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            nextText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: plan.currentShoeOutgrown ? _staleColor : _titleColor,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '実測 ${plan.measuredFootLengthCm.toStringAsFixed(1)}cm'
          '（${plan.measuredAt.year}/${plan.measuredAt.month}/'
          '${plan.measuredAt.day}）をもとに予測',
          style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// [SizeGuideExportCard] を画面外に1フレームだけ描画して PNG バイト列にする。
///
/// Overlay に画面外（左に大きくオフセット）の Positioned として挿入するため、
/// ユーザーには見えないが通常どおりレイアウト・描画され、RepaintBoundary から
/// そのまま画像化できる。テーマ（選択中の子のカラー）も MaterialApp から継承する。
Future<Uint8List?> captureSizeGuideImage({
  required BuildContext context,
  required ChildProfile child,
  String? displayName,
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -SizeGuideExportCard.designWidth * 2,
      top: 0,
      width: SizeGuideExportCard.designWidth,
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizeGuideExportCard(child: child, displayName: displayName),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // レイアウトと描画が終わるまで待つ（余裕をみて2フレーム）。
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final render = boundaryKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return null;
    final image = await render.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
