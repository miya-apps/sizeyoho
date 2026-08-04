import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_info.dart';
import '../growth/clothing_size_guide.dart';
import '../growth/diaper_master.dart';
import '../growth/diaper_master_data.g.dart' show kDiaperBrands;
import '../growth/diaper_size_guide.dart';
import '../models/child_profile.dart';
import '../models/diaper_records.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import '../monetization/pro_status.dart';
import '../screens/clothing_guide_screen.dart'
    show GuideSizeTab, seasonAccentColor, seasonBaseColor, seasonIconData;
import '../widgets/diaper_badge.dart';
import '../widgets/diaper_slot_summary_card.dart';
import '../widgets/diaper_status_pill.dart';
import '../widgets/growth_charts.dart';
import '../widgets/guide_summary_card.dart';
import '../widgets/shoe_forecast_steps.dart';
import 'square_capture.dart';

/// 画像保存で選べる1枚ぶんの書き出し対象。
/// サイズガイド3カテゴリに加えて、成長曲線・SDスコアの2グラフも
/// 同じ正方形カード（[GuideExportCard]）として書き出せる。
enum SizeExportItem { growthChart, sdChart, diaper, clothing, shoe }

/// 書き出し対象の短い日本語ラベル（選択UI・見出し・ファイル名に使う）。
String sizeExportItemLabel(SizeExportItem item) => switch (item) {
      SizeExportItem.growthChart => '成長曲線',
      SizeExportItem.sdChart => 'SDスコア',
      SizeExportItem.diaper => 'おむつ',
      SizeExportItem.clothing => '洋服',
      SizeExportItem.shoe => '靴',
    };

/// サイズ予報タブのサブタブ → 書き出し対象への対応。
SizeExportItem exportItemForGuideTab(GuideSizeTab tab) => switch (tab) {
      GuideSizeTab.diaper => SizeExportItem.diaper,
      GuideSizeTab.clothing => SizeExportItem.clothing,
      GuideSizeTab.shoe => SizeExportItem.shoe,
    };

/// おむつ・洋服・靴・成長曲線・SDスコアのいずれか1枚ぶんの「サイズ予報」を、
/// Instagram の正方形投稿にそのまま使える画像として書き出す。
///
/// 画面表示用のウィジェット（[DiaperGuideView] など）はスクロール・タップ
/// 操作を前提にしたレイアウトのため、共有・保存専用に組み直した固定幅の
/// カード（[GuideExportCard]）を画面外に描画し、[captureSquareImage] で
/// 正方形の PNG にする。
Future<Uint8List?> captureGuideSquareImage({
  required BuildContext context,
  required SizeExportItem item,
  required ChildProfile child,
  String? displayName,
  bool maskName = false,
  double pixelRatio = 3.0,
}) {
  return captureSquareImage(
    context: context,
    contentWidth: GuideExportCard.designWidth,
    // アプリ画面と同じ「白＋テーマ淡色」の背景（透過PNGにしない）。
    // 書き出し画像は単体で流れるため、画面よりやや濃くして
    // 「この子のテーマカラー」が伝わるようにする。
    background: Color.alphaBlend(
      child.themeColor.withValues(alpha: 0.18),
      Colors.white,
    ),
    contentBuilder: (_) => GuideExportCard(
      item: item,
      child: child,
      displayName: displayName,
      maskName: maskName,
    ),
  );
}

/// 1枚ぶんの書き出しカード本体（正方形化される前の、固定幅・
/// 自然な高さのコンテンツ）。[captureGuideSquareImage] が内部で使うほか、
/// ウィジェットテストからも直接描画・検証できるよう公開している。
class GuideExportCard extends StatelessWidget {
  const GuideExportCard({
    super.key,
    required this.item,
    required this.child,
    this.displayName,
    this.maskName = false,
  });

  final SizeExportItem item;
  final ChildProfile child;
  final String? displayName;

  /// true なら名前を出さず、お子様のアイコン（写真ではなく選択中の絵柄）
  /// だけを見出しに添える（「書き出し時に名前を伏せる」設定用）。
  final bool maskName;

  /// 画像の基準幅（論理px）＝正方形の一辺。内容がこれより高い場合は
  /// [captureSquareImage] 側で全体が比例縮小されて収まる。
  static const double designWidth = 420;

  static const _titleColor = Color(0xFF1A1A1A);

  /// 見出しの種別名。グラフは「〜のサイズ予報」だと不正確なので
  /// グラフ名をそのまま使う。
  String get _itemTitle => switch (item) {
        SizeExportItem.growthChart => '成長曲線',
        SizeExportItem.sdChart => '成長グラフ（SDスコア）',
        _ => '${sizeExportItemLabel(item)}サイズ予報',
      };

  /// 見出し直下の説明文。5枚で同じ位置・同じ大きさに揃うよう、
  /// 本文（縮小されうる）ではなくカード側の固定領域に置く。
  String get _leadText => switch (item) {
        SizeExportItem.growthChart => '標準的な成長曲線（帯）と実測の記録（●）の重ね合わせです',
        SizeExportItem.sdChart => '0が平均。同じ月齢の標準と比べた位置（SD）の推移です',
        SizeExportItem.diaper => '体重の記録と各社公表のめやすから計算した目安です',
        SizeExportItem.clothing => '直近の成長トレンドから予測した目安です',
        SizeExportItem.shoe => '実測と購入の記録から予測した目安です',
      };

  /// フッターの注記。予測もの3種はガード文言、グラフ2種は出典・読み方。
  /// これも5枚で同じ位置・同じ大きさになるようカード側の固定領域に置く。
  String get _footnote => switch (item) {
        SizeExportItem.growthChart => '※基準：日本小児内分泌学会 標準成長曲線（2000年度データ）',
        SizeExportItem.sdChart => '※±2SDの帯（緑の破線の間）がおおよその一般的な範囲の目安です',
        _ => '※あくまで目安です。成長には個人差があり、'
            '実際のサイズ感は製品や体型によって異なります。',
      };

  /// 見出しに添えるお子様のアイコン。写真が設定されていても、共有先での
  /// 匿名性を守るため（名前伏せ設定に関係なく）必ず選択中のアイコン絵柄を使う。
  Widget _avatar() {
    final fg = Color.lerp(child.themeColor, Colors.black, 0.55)!;
    return CircleAvatar(
      radius: 14,
      backgroundColor: Color.alphaBlend(
        child.themeColor.withValues(alpha: 0.45),
        Colors.white,
      ),
      child: Icon(child.iconData, size: 16, color: fg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final body = switch (item) {
      SizeExportItem.growthChart =>
        _ChartExportBody(child: child, isSdScore: false),
      SizeExportItem.sdChart =>
        _ChartExportBody(child: child, isSdScore: true),
      SizeExportItem.diaper => _DiaperExportBody(child: child),
      SizeExportItem.clothing => _ClothingExportBody(child: child),
      SizeExportItem.shoe => _ShoeExportBody(child: child),
    };

    // カード自体を正方形の固定サイズにし、ヘッダー（見出し・説明文）と
    // フッター（注記・クレジット）は5種類とも同じ位置・同じ大きさで描く。
    // 高さが変わるのは本文だけで、収まらない場合は本文だけを比例縮小する。
    // （以前はカード全体を縮小していたため、内容の多い種類ほど見出しまで
    // 小さくなり、5枚並べたときにバランスが揃わなかった。）
    return Material(
      color: Colors.transparent,
      child: Container(
        width: designWidth,
        height: designWidth,
        // 外周はゆったりめに取り、共有先でスタンプや文字を足す余地を残す。
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ヘッダー（アイコン＋見出し＋作成日） ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatar(),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    maskName
                        ? _itemTitle
                        : '${displayName ?? child.displayName} の$_itemTitle',
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
            // テーマカラーのアクセントライン（見出しの下線）。
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: child.themeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text(
              _leadText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
            ),
            // ── 本文（この領域だけが種類ごとに伸縮・縮小される） ──
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: designWidth - 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
            // ── フッター（注記＋クレジット） ──
            // SNS（Instagram）で単体で流れる前提のため、アプリ内の免責事項と
            // 同じトーンの注記と、出どころ（©＋公開サイトURL）を画像自体に
            // 焼き込む。予測もの3種はガード文言、グラフ2種は出典・読み方。
            Text(
              _footnote,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '© ${now.year} $kAppName　$kWebDisplayUrl',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成長曲線／SDスコアグラフの本体。
///
/// 画面のグラフと同じ共有ウィジェット（[GrowthCurveChart] / [SdScoreChart]）を
/// 正方形カードに収まる固定の高さで再描画する（画面のスクショではない）。
/// 表示範囲は子の現在年齢に合わせて自動選択し、年齢は暦月齢基準。
class _ChartExportBody extends StatelessWidget {
  const _ChartExportBody({required this.child, required this.isSdScore});

  final ChildProfile child;
  final bool isSdScore;

  /// カード内のグラフ描画高さ（論理px）。ヘッダー・補足・フッターと
  /// 合わせて正方形にほどよく収まるよう固定する。
  static const double _chartHeight = 300;

  /// 生年月日基準（暦月齢）のプロット点を年齢昇順で返す。
  List<GrowthRecordPoint> _recordPoints() {
    final base = child.birthDate;
    final pts =
        child.growthRecords
            .map(
              (r) => (
                date: r.date,
                age: r.date.difference(base).inDays / 365.25,
                h: r.heightCm,
                w: r.weightKg,
              ),
            )
            .where((r) => r.age >= 0)
            .toList()
          ..sort((a, b) => a.age.compareTo(b.age));
    return pts;
  }

  /// 「最新の記録：2026/7/28　身長 87.0cm・体重 12.3kg」の1行。
  String? _latestRecordLine(List<GrowthRecordPoint> points) {
    for (final r in points.reversed) {
      final hasH = r.h != null && r.h! > 0;
      final hasW = r.w != null && r.w! > 0;
      if (!hasH && !hasW) continue;
      final d = r.date;
      final values = [
        if (hasH) '身長 ${r.h!.toStringAsFixed(1)}cm',
        if (hasW) '体重 ${formatWeightKg(r.w!)}kg',
      ].join('・');
      return '最新の記録：${d.year}/${d.month}/${d.day}　$values';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final points = _recordPoints();
    if (points.isEmpty) {
      return const _EmptyNote(message: '身長・体重の記録がまだありません');
    }

    final isBoy = child.gender == Gender.male;
    final ageRangeYears = autoGrowthAgeRangeYears(child.birthDate);
    final latestLine = _latestRecordLine(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSdScore) ...[
                const Center(child: SdChartLegend()),
                const SizedBox(height: 4),
              ],
              SizedBox(
                height: _chartHeight,
                child: isSdScore
                    ? SdScoreChart(
                        isBoy: isBoy,
                        recordPoints: points,
                        ageRangeYears: ageRangeYears,
                      )
                    : GrowthCurveChart(
                        isBoy: isBoy,
                        recordPoints: points,
                        ageRangeYears: ageRangeYears,
                      ),
              ),
            ],
          ),
        ),
        if (latestLine != null) ...[
          const SizedBox(height: 6),
          Text(
            latestLine,
            textAlign: TextAlign.center,
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
}

/// 洋服カテゴリの本体：現在の身長＋成長トレンド、季節ごとの購入サイズ表。
class _ClothingExportBody extends StatelessWidget {
  const _ClothingExportBody({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final guide = ClothingSizeGuideCalculator.compute(child);
    if (!guide.hasData) {
      return _EmptyNote(message: guide.message ?? '身長の記録が足りません');
    }
    return _SeasonTable(entries: guide.timeline);
  }
}

/// 季節ごとの購入サイズを時系列（今シーズンが先頭）の行で並べた表。
class _SeasonTable extends StatelessWidget {
  const _SeasonTable({required this.entries});

  final List<ClothingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 5),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 15,
              color: seasonAccentColor(entries[i].title).withValues(alpha: 0.65),
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
        // セル幅が足りないとき（狭い端末・大きいサイズ表記）は
        // はみ出さず縮小して1行に収める。
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
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

/// 靴カテゴリの本体。
///
/// 正方形を活かすため、上段に「いまの目安・いまの靴」の数値サマリー、
/// 下段に洋服の季節行と同じ視覚言語の「いま → 次の購入 → その先」の
/// ステップ表示を置く（変更前は白カード1枚だけで正方形の半分が余白だった）。
class _ShoeExportBody extends StatelessWidget {
  const _ShoeExportBody({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final plan = computeShoeSizePurchasePlan(child);

    if (plan == null) {
      return const _EmptyNote(message: '足長の記録がまだありません');
    }

    // 画面（靴ガイド）と同じルール：購入時期の先読みは Pro 版のみ。
    final isPro = ProStatus.isPro.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShoeMetricsCard(plan: plan),
        const SizedBox(height: 16),
        // 警告はステップの上（「いま」行の上）に置き、「いま」行の目安サイズが
        // そのまま買い替えおすすめであることが伝わるようにする。
        if (plan.currentShoeOutgrown) ...[
          ShoeOutgrownBanner(lastPurchaseSizeCm: plan.lastPurchase?.sizeCm),
          const SizedBox(height: 8),
        ],
        ShoeCurrentStepRow(plan: plan),
        if (isPro) ShoeForecastStepRows(plan: plan),
        const SizedBox(height: 10),
        Text(
          '※実測した日からの成長ぶんと、つま先余裕'
          '（+${shoeToeAllowanceCm.toStringAsFixed(1)}cm）を見込んだ目安です',
          style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

/// おむつカテゴリの本体：現在の体重＋成長トレンド、選択中の枠ごとのサイズ。
///
/// 画面用の [DiaperSlotSummaryCard] は1枠が縦に大きく、3枠選ぶと正方形に
/// 収まらないため、書き出し用にはサイズ情報を横1行にまとめたコンパクト版
/// （[_DiaperExportSlotCard]）を使う。
class _DiaperExportBody extends StatelessWidget {
  const _DiaperExportBody({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final latestWeight = latestWeightRecord(child.growthRecords);
    if (latestWeight == null) {
      return const _EmptyNote(
        message: 'サイズの表示には体重の記録が必要です',
      );
    }

    final baselineSd = computeWeightBaselineSd(child);
    final isBoy = child.gender == Gender.male;
    final slots = [...child.diaperSlots]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GuideSummaryCard(
          primaryLabel: '現在の体重',
          primaryValue: '${formatWeightKg(latestWeight.weightKg!)} kg',
          trendLabel: '成長トレンド',
          trendValue:
              baselineSd != null ? formatBaselineSdScoreValue(baselineSd) : '—',
          showTrendHelp: false,
        ),
        const SizedBox(height: 10),
        if (slots.isEmpty)
          const _EmptyNote(message: '比較したいおむつが選択されていません')
        else
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _diaperSlotCard(slots[i], isBoy),
          ],
      ],
    );
  }

  Widget _diaperSlotCard(DiaperSlot slot, bool isBoy) {
    final series = findDiaperSeriesById(kDiaperBrands, slot.seriesId);
    if (series == null) return const SizedBox.shrink();
    final guide = computeDiaperSlotGuide(
      child: child,
      ladder: series.bandsFor(slot.type),
    );
    return _DiaperExportSlotCard(
      series: series,
      type: slot.type,
      isBoy: isBoy,
      guide: guide,
    );
  }
}

/// 書き出し画像用の1枠カード（コンパクト版）。
///
/// 1行目：バッジ＋シリーズ名＋タイプ／状態バッジ、
/// 2行目：サイズ情報（ゆらぎ中は「M → L」を横並びに）、
/// 必要なら3行目に使える見込みの補足。画面用カードの縦積みレイアウトを
/// 横向きに畳んで、3枠でも正方形に収まる高さにしている。
class _DiaperExportSlotCard extends StatelessWidget {
  const _DiaperExportSlotCard({
    required this.series,
    required this.type,
    required this.isBoy,
    required this.guide,
  });

  final DiaperSeries series;
  final DiaperType type;
  final bool isBoy;
  final DiaperSlotGuide? guide;

  static const _titleColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final brand = findDiaperBrandById(kDiaperBrands, series.brandId);
    final name = brand == null
        ? series.displayName
        : diaperDisplayName(brand: brand, series: series, type: type);
    final pillKind = diaperStatusPillKind(guide);
    final body = _buildBody();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              DiaperBadge(series: series, type: type, isBoy: isBoy, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              DiaperTypeBadge(type: type),
              if (pillKind != null) ...[
                const SizedBox(width: 5),
                DiaperStatusPill(kind: pillKind),
              ],
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 7),
            body,
          ],
        ],
      ),
    );
  }

  /// 2行目以降のサイズ情報。上限超過・判定不能では出さない。
  Widget? _buildBody() {
    final guide = this.guide;
    if (guide == null) return null;
    switch (guide.fit.status) {
      case DiaperFitStatus.clean:
      case DiaperFitStatus.inTransition:
        break;
      case DiaperFitStatus.belowRange:
        return Text(
          '体重がこのシリーズの対象より軽いです',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        );
      case DiaperFitStatus.aboveRange:
        return null;
    }

    // クリーン・最大到達：「サイズ（範囲）」1行＋見込みの補足。
    if (guide.fit.status == DiaperFitStatus.clean) {
      final current = guide.currentBand!;
      final forecast =
          guide.fit.isMaxSize ? guide.lowerSizeEndForecast : guide.nextSizeForecast;
      return _centeredLine([
        DiaperSizeChip(label: current.sizeLabel),
        const SizedBox(width: 5),
        _rangeText(current),
        if (forecast != null && forecast.weeksUntil > 0) ...[
          const SizedBox(width: 8),
          _noteText(
            '${formatDiaperForecastMonth(forecast.approxDate)}まで使える見込み'
            '（残り約${roundedDiaperWeeks(forecast.weeksUntil)}週間）',
          ),
        ],
      ]);
    }

    // ゆらぎの中：「M（範囲） → L（範囲）」を横1行に。
    final lower = guide.currentBand!;
    final upper = guide.nextBand!;
    final end = guide.lowerSizeEndForecast;
    final String? lowerNote;
    if (end != null && end.weeksUntil > 0) {
      lowerNote = guide.fit.assertiveTransition
          ? '${formatDiaperForecastMonth(end.approxDate)}まで使える見込み'
              '（残り約${roundedDiaperWeeks(end.weeksUntil)}週間）'
          : '※${formatDiaperForecastMonth(end.approxDate)}まで';
    } else {
      lowerNote = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _centeredLine([
          DiaperSizeChip(label: lower.sizeLabel),
          const SizedBox(width: 5),
          _rangeText(lower),
          const SizedBox(width: 7),
          const Text(
            '→',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A8A8A),
            ),
          ),
          const SizedBox(width: 7),
          DiaperSizeChip(label: upper.sizeLabel),
          const SizedBox(width: 5),
          _rangeText(upper),
        ]),
        if (lowerNote != null) ...[
          const SizedBox(height: 3),
          _noteText('${lower.sizeLabel}は$lowerNote'),
        ],
      ],
    );
  }

  /// 幅が足りないときも1行を保つ（縮小して収める）センタリング行。
  Widget _centeredLine(List<Widget> children) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      );

  Widget _rangeText(DiaperSizeBand band) => Text(
        '（${diaperRangeLabel(band)}）',
        style: TextStyle(fontSize: 11.5, color: Colors.grey[700], height: 1.2),
      );

  Widget _noteText(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: Colors.grey[600], height: 1.3),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
