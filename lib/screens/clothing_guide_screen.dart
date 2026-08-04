import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/adaptive_layout.dart';
import '../growth/clothing_size_guide.dart';
import '../models/child_profile.dart';
import '../widgets/guide_summary_card.dart';
import 'diaper_guide_screen.dart';
import 'shoe_guide_screen.dart';

/// 「サイズ予報」タブ内の表示中サブタブ（成長の順序：おむつ→洋服→靴）。
/// AppShell がヘッダーの「画像保存」ボタンの文言・書き出し内容を
/// 現在のサブタブに合わせるために、[ClothingGuideScreen.modeNotifier]
/// 経由で参照する。
enum GuideSizeTab { diaper, clothing, shoe }

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
    this.modeNotifier,
  });

  final ChildProfile child;

  /// 靴の記録などを保存するときに呼ぶ（AppShell が永続化する）。
  final ValueChanged<ChildProfile> onUpdateChild;

  /// 表示中のサブタブを AppShell に伝える（画像保存ボタンの文言・書き出し
  /// 対象の切り替えに使う）。初期値の反映・実際に表示している内容（おむつ
  /// 設定OFF時のフォールバック含む）は毎フレーム同期する。
  final ValueNotifier<GuideSizeTab>? modeNotifier;

  /// カードのデザイン基準幅（論理px）。スクショ画像もこの幅で描画する想定。
  /// 表示時は [kContentMaxWidth] を上限（= 1.5倍）として比例拡大され、
  /// 他画面と最大幅が揃う。
  static const double _designWidth = 400;

  static const _currentSeasonBadgeBg = Color(0xFFFFF3E0);
  static const _currentSeasonBadgeText = Color(0xFFE65100);

  @override
  State<ClothingGuideScreen> createState() => _ClothingGuideScreenState();
}

class _ClothingGuideScreenState extends State<ClothingGuideScreen> {
  /// 初期表示は従来どおり洋服ガイド。
  GuideSizeTab _mode = GuideSizeTab.clothing;

  @override
  void initState() {
    super.initState();
    // 子どもを切り替えると画面ごと作り直されるため、直前に表示していた
    // サブタブ（おむつ/洋服/靴）を modeNotifier から引き継ぐ。
    // 新しい子でおむつガイドがOFFの場合は _effectiveMode が洋服に丸める。
    final initial = widget.modeNotifier?.value;
    if (initial != null) _mode = initial;
  }

  /// おむつガイドタブを出すか（子どもごとのオプトイン設定）。
  bool get _showDiaper => widget.child.diaperGuideEnabled;

  /// 設定OFF中におむつモードが残っていた場合は洋服ガイドへ丸める。
  GuideSizeTab get _effectiveMode =>
      (!_showDiaper && _mode == GuideSizeTab.diaper)
          ? GuideSizeTab.clothing
          : _mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = _effectiveMode;

    // AppShell の「画像保存」ボタンが現在の表示に合わせて文言・書き出し
    // 対象を切り替えるための通知（初期値・フォールバックも含めて毎フレーム
    // 同期する。値が同じ場合は ValueNotifier 側で通知が抑制される）。
    final notifier = widget.modeNotifier;
    if (notifier != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.value = mode;
      });
    }

    final subtitle = switch (mode) {
      GuideSizeTab.diaper => '体重の記録と各社公表のめやすから計算（目安）',
      GuideSizeTab.clothing => '直近の成長トレンドから予測（目安）',
      GuideSizeTab.shoe => '実測と購入の記録から予測（目安）',
    };

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
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: switch (mode) {
                GuideSizeTab.diaper => DiaperGuideView(
                    child: widget.child,
                    onUpdateChild: widget.onUpdateChild,
                  ),
                GuideSizeTab.clothing => _buildClothingBody(),
                GuideSizeTab.shoe => ShoeGuideView(
                    child: widget.child,
                    onUpdateChild: widget.onUpdateChild,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 「(おむつガイド /) 洋服ガイド / 靴ガイド」の切り替えセグメント。
  /// アイコン＋文字で直感的に。高さ・パディングを固定して文字が
  /// 切れないようにする（compact 密度だと縦に潰れて欠けることがある）。
  /// おむつガイド表示時は3つになるため、パディング・ラベル幅を詰めて
  /// 狭い端末でも収まるようにする（ラベルは FittedBox で自動縮小）。
  Widget _buildModeSwitcher(ColorScheme scheme) {
    final compact = _showDiaper;
    return SegmentedButton<GuideSizeTab>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 16),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        // グラフ画面の年齢選択（テーマ色ベタ塗り＋白太字）と同じ見せ方に
        // 揃え、選択中であることをはっきり伝える。
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
      ),
      segments: [
        if (_showDiaper)
          ButtonSegment(
            value: GuideSizeTab.diaper,
            icon: const PhosphorIcon(PhosphorIconsRegular.baby, size: 18),
            label: _segmentLabel('おむつ', compact),
          ),
        ButtonSegment(
          value: GuideSizeTab.clothing,
          icon: const PhosphorIcon(PhosphorIconsRegular.shirtFolded, size: 18),
          label: _segmentLabel(_showDiaper ? '洋服' : '洋服ガイド', compact),
        ),
        ButtonSegment(
          value: GuideSizeTab.shoe,
          icon: const PhosphorIcon(PhosphorIconsRegular.sneaker, size: 18),
          label: _segmentLabel(_showDiaper ? '靴' : '靴ガイド', compact),
        ),
      ],
      selected: {_effectiveMode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  /// セグメントのラベル。Flutter Web では初回描画時に日本語フォントの
  /// 読み込みが間に合わず、代替字形でテキスト幅が実測より狭く計測されて
  /// 文字が切れることがある。幅をフォント計測に依存しない固定値にし、
  /// 万一収まらない場合も FittedBox の縮小で見切れを防ぐ。
  /// 3タブ時（[compact]）は「ガイド」を省いた短いラベル＋狭い幅にする。
  static Widget _segmentLabel(String text, bool compact) => SizedBox(
        width: compact ? 44 : 68,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, softWrap: false),
        ),
      );

  Widget _buildClothingBody() {
    final guide = ClothingSizeGuideCalculator.compute(widget.child);
    // おむつガイド（DiaperGuideView）と外枠の組み方を完全に揃える：
    // Center > ConstrainedBox(maxWidth) > Padding という同じ順番・同じ値に
    // することで、タブ切り替え時に枠の幅・位置がずれて画面が揺らがないよう
    // にする（パディングを ConstrainedBox の外に置くと、幅が広い画面で
    // 「制限後に引く」おむつ側と「引いてから制限する」洋服側の実効幅が
    // ズレていた）。
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: !guide.hasData
                ? _EmptyState(message: guide.message ?? 'データ不足')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // サマリーカード（現在の身長・成長トレンド）は、おむつ
                      // ガイドと文字サイズを完全に揃えるため、季節グリッドの
                      // FittedBox 拡縮の対象外にする（変更依頼2・§8）。
                      _SummaryCard(guide: guide),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: ClothingGuideScreen._designWidth,
                          child: ClothingGuideCard(guide: guide),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 洋服ガイドの本体カード（「サイズ予測」タイトル〜季節グリッド）。
///
/// サマリー（現在の身長・成長トレンド）は含まない：おむつガイドと文字サイズを
/// 揃えるため、呼び出し側で FittedBox 拡縮の外に別途置いている（§8）。
/// 固定幅前提の自己完結ウィジェットで、画面表示では FittedBox で拡縮される。
class ClothingGuideCard extends StatelessWidget {
  const ClothingGuideCard({super.key, required this.guide});

  final ClothingGuideResult guide;

  @override
  Widget build(BuildContext context) {
    // タイトル・サブタイトルは画面上部の切り替えセグメントに集約した。
    // 靴のサマリーは置かない（靴の記録・予測は「靴ガイド」表示に集約）。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
    return GuideSummaryCard(
      primaryLabel: '現在の身長',
      primaryValue: guide.currentHeightCm != null
          ? '${guide.currentHeightCm!.toStringAsFixed(1)} cm'
          : '—',
      trendLabel: '成長トレンド',
      trendValue: guide.baselineSdScore != null
          ? formatBaselineSdScoreValue(guide.baselineSdScore!)
          : '—',
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
