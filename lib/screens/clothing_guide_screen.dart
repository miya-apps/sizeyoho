import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/adaptive_layout.dart';
import '../growth/clothing_size_guide.dart';
import '../models/child_profile.dart';
import 'shoe_guide_screen.dart';

/// LMS ベースライン SD からサイズを予測する「洋服ガイド」タブ。
/// 上部の切り替えで「洋服ガイド（季節ごとの服サイズ）」と
/// 「靴ガイド（実測・購入の記録と買い替え予測）」を同一タブ内で切り替える。
///
/// 洋服側のコンテンツは固定幅の [ClothingGuideCard] を FittedBox で
/// 比例拡大して表示する。大画面では上限倍率まで全体が大きくなり、
/// それ以上は中央寄せで余白を出す。
class ClothingGuideScreen extends StatefulWidget {
  const ClothingGuideScreen({
    super.key,
    required this.child,
    required this.onUpdateChild,
  });

  final ChildProfile child;

  /// 靴の記録などを保存するときに呼ぶ（AppShell が永続化する）。
  final ValueChanged<ChildProfile> onUpdateChild;

  /// カードのデザイン基準幅（論理px）。スクショ画像もこの幅で描画する想定。
  /// 表示時は [kContentMaxWidth] を上限（= 1.5倍）として比例拡大され、
  /// 他画面と最大幅が揃う。
  static const double _designWidth = 400;

  static const _titleColor = Color(0xFF1A1A1A);
  static const _currentSeasonBadgeBg = Color(0xFFFFF3E0);
  static const _currentSeasonBadgeText = Color(0xFFE65100);

  @override
  State<ClothingGuideScreen> createState() => _ClothingGuideScreenState();
}

class _ClothingGuideScreenState extends State<ClothingGuideScreen> {
  /// 0 = 洋服ガイド, 1 = 靴ガイド。
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),
            _buildModeSwitcher(scheme),
            const SizedBox(height: 3),
            Text(
              _mode == 0 ? '直近の成長トレンドから予測（目安）' : '実測と購入の記録から予測（目安）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _mode == 0
                  ? _buildClothingBody()
                  : ShoeGuideView(
                      child: widget.child,
                      onUpdateChild: widget.onUpdateChild,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 「洋服ガイド / 靴ガイド」の切り替えセグメント（タブ上部中央）。
  /// アイコン＋文字で直感的に。高さ・パディングを固定して文字が
  /// 切れないようにする（compact 密度だと縦に潰れて欠けることがある）。
  Widget _buildModeSwitcher(ColorScheme scheme) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        selectedBackgroundColor: scheme.primary.withValues(alpha: 0.18),
        selectedForegroundColor: scheme.primary,
        foregroundColor: Colors.grey[700],
      ),
      segments: [
        ButtonSegment(
          value: 0,
          icon: const PhosphorIcon(PhosphorIconsRegular.shirtFolded, size: 18),
          label: _segmentLabel('洋服ガイド'),
        ),
        ButtonSegment(
          value: 1,
          icon: const PhosphorIcon(PhosphorIconsRegular.sneaker, size: 18),
          label: _segmentLabel('靴ガイド'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  /// セグメントのラベル。Flutter Web では初回描画時に日本語フォントの
  /// 読み込みが間に合わず、代替字形でテキスト幅が実測より狭く計測されて
  /// 文字が切れることがある。幅をフォント計測に依存しない固定値にし、
  /// 万一収まらない場合も FittedBox の縮小で見切れを防ぐ。
  static Widget _segmentLabel(String text) => SizedBox(
        width: 68,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, softWrap: false),
        ),
      );

  Widget _buildClothingBody() {
    final guide = ClothingSizeGuideCalculator.compute(widget.child);
    if (!guide.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [_EmptyState(message: guide.message ?? 'データ不足')],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: ClothingGuideScreen._designWidth,
              child: ClothingGuideCard(child: widget.child, guide: guide),
            ),
          ),
        ),
      ),
    );
  }
}

/// 洋服ガイドの本体カード（タイトル〜季節グリッド）。
///
/// 固定幅前提の自己完結ウィジェット。画面表示では FittedBox で拡縮され、
/// 将来のスクショ共有機能では RepaintBoundary で囲んでこのまま画像化する。
class ClothingGuideCard extends StatelessWidget {
  const ClothingGuideCard({
    super.key,
    required this.child,
    required this.guide,
  });

  final ChildProfile child;
  final ClothingGuideResult guide;

  @override
  Widget build(BuildContext context) {
    // タイトル・サブタイトルは画面上部の切り替えセグメントに集約した。
    // 靴のサマリーは置かない（靴の記録・予測は「靴ガイド」表示に集約）。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryCard(guide: guide),
        const SizedBox(height: 10),
        Text(
          'サイズ予測',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        _SeasonList(entries: guide.timeline),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.guide});

  final ClothingGuideResult guide;

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
            child: _SummaryMetric(
              label: '現在の身長',
              value: guide.currentHeightCm != null
                  ? '${guide.currentHeightCm!.toStringAsFixed(1)} cm'
                  : '—',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _SummaryMetric(
              label: '成長トレンド',
              value: guide.baselineSdScore != null
                  ? formatBaselineSdScore(guide.baselineSdScore!)
                  : '—',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
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
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ClothingGuideScreen._titleColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 季節ごとの購入サイズを時系列（今シーズンが先頭）で縦に並べたリスト。
/// 行間に「次の季節へ流れる」下向き矢印を挟み、上から順に季節が
/// 移り変わっていくことをデザインで示す。矢印は行き先（次の季節）の
/// 差し色で塗り、視線を自然に下へ誘導する。
class _SeasonList extends StatelessWidget {
  const _SeasonList({required this.entries});

  final List<ClothingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 先頭行の「今シーズン」バッジが行の上枠にかかるぶんの余白。
        const SizedBox(height: 6),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 18,
              color: seasonAccentColor(entries[i].title)
                  .withValues(alpha: 0.65),
            ),
          _SeasonRow(entry: entries[i], isCurrentSeason: i == 0),
        ],
      ],
    );
  }
}

/// 1季節ぶんの行：季節ラベル｜今年のサイズ → 来年のサイズ（強調）。
class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.entry, required this.isCurrentSeason});

  final ClothingTimelineEntry entry;
  final bool isCurrentSeason;

  @override
  Widget build(BuildContext context) {
    final accent = seasonAccentColor(entry.title);
    final titleColor = Color.lerp(accent, Colors.black, 0.35)!;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: seasonBaseColor(entry.title),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          // 季節ラベル（アイコン＋名前・差し色）
          PhosphorIcon(
            seasonIconData(entry.title),
            size: 22,
            color: accent,
            duotoneSecondaryColor: accent.withValues(alpha: 0.45),
            duotoneSecondaryOpacity: 1,
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 44,
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 今年・来年のサイズ。年ラベルで時系列が伝わるため矢印は置かず、
          // 均等な余白でバランスを取る（来年は「白地＋差し色の枠」で強調）。
          Expanded(
            child: _YearSizeCell(
              year: formatClothingTargetYearLabel(entry.targetDateThisYear),
              sizeCm: entry.thisYearJustSize,
              estimatedHeightCm: entry.thisYearEstimatedHeightCm,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _YearSizeCell(
              year: formatClothingTargetYearLabel(entry.targetDateNextYear),
              sizeCm: entry.nextYearJustSize,
              estimatedHeightCm: entry.nextYearEstimatedHeightCm,
              highlightAccent: accent,
            ),
          ),
        ],
      ),
    );

    if (!isCurrentSeason) return row;

    // 今シーズンの行は左上にバッジを重ねる（行の上枠に少しかかる位置）。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        row,
        Positioned(
          top: -7,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ClothingGuideScreen._currentSeasonBadgeBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: ClothingGuideScreen._currentSeasonBadgeText
                    .withValues(alpha: 0.30),
              ),
            ),
            child: const Text(
              '📍今シーズン',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: ClothingGuideScreen._currentSeasonBadgeText,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 「2026年 90cm ＋ 推定身長」の1セル。[highlightAccent] を渡すと
/// 旧 2×2 カードの来年枠と同じ「白地＋季節色の枠線」で強調する。
class _YearSizeCell extends StatelessWidget {
  const _YearSizeCell({
    required this.year,
    required this.sizeCm,
    required this.estimatedHeightCm,
    this.highlightAccent,
  });

  final String year;
  final int sizeCm;
  final double estimatedHeightCm;
  final Color? highlightAccent;

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${sizeCm}cm',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '推定${estimatedHeightCm.toStringAsFixed(1)}cm',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
            height: 1.1,
          ),
        ),
      ],
    );

    if (highlightAccent == null) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlightAccent!, width: 1.5),
      ),
      child: content,
    );
  }
}

/// 季節のベース色（行の背景）。
///
/// 配色ルール：
/// - 各季節は「ベース（背景）＋差し色（アクセント）」の2色構成
/// - 4季節そろえたときに彩度・明度のバランスが取れていること
/// - どのテーマカラー（くすみパステル）を背景に敷いても埋もれない、
///   かつケンカしない明るさ（不透明色なのでテーマ色の影響を受けない）
/// - 季節のモチーフを感じる色相
///   （春=桜、夏=水面、秋=実り・紅葉、冬=雪空）
Color seasonBaseColor(String seasonLabel) {
  switch (seasonLabel) {
    case '春服':
      return const Color(0xFFF9E7EC); // 桜のうす紅
    case '夏服':
      return const Color(0xFFE2F1F6); // 水面のうす水色
    case '秋服':
      return const Color(0xFFF6ECDC); // 実りのうす黄土
    case '冬服':
      return const Color(0xFFE7EBF4); // 雪空のうす青灰
    default:
      return Colors.white;
  }
}

/// 季節の差し色（アイコン・枠線・強調）。ベース色と同系の色相を
/// 一段濃くしたミッドトーンで、白地・ベース地の両方で読める濃さにする。
/// （サイズガイド書き出し画像でも同じ配色を使う。）
Color seasonAccentColor(String seasonLabel) {
  switch (seasonLabel) {
    case '春服':
      return const Color(0xFFBF5677); // 桜ローズ
    case '夏服':
      return const Color(0xFF2E7FA8); // マリンブルー
    case '秋服':
      return const Color(0xFFAD6B26); // こはく・紅葉
    case '冬服':
      return const Color(0xFF52659C); // 冬の夜空ネイビー
    default:
      return Colors.grey.shade700;
  }
}

/// 季節カード・書き出し画像で使う衣服モチーフのアイコン。
PhosphorDuotoneIconData seasonIconData(String seasonLabel) {
  return switch (seasonLabel) {
    '春服' => PhosphorIconsDuotone.shirtFolded,
    '夏服' => PhosphorIconsDuotone.tShirt,
    '秋服' => PhosphorIconsDuotone.hoodie,
    '冬服' => PhosphorIconsDuotone.beanie,
    _ => PhosphorIconsDuotone.tShirt,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.checkroom_outlined,
              size: 44,
              color: Colors.grey.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
