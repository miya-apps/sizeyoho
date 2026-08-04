import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/adaptive_layout.dart';
import '../growth/clothing_size_guide.dart' show formatBaselineSdScoreValue;
import '../growth/diaper_master.dart';
import '../growth/diaper_master_data.g.dart';
import '../growth/diaper_size_guide.dart';
import '../models/child_profile.dart';
import '../models/diaper_records.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import '../widgets/diaper_badge.dart';
import '../widgets/diaper_slot_summary_card.dart';
import '../widgets/guide_summary_card.dart';

/// おむつの選択・予報ビュー（サイズ予報タブ内の「おむつガイド」表示）。
///
/// 設計方針（重要）：
/// - 「いま使っているサイズ」は記録させない。選択した各シリーズの公表体重帯に
///   体重を照らし、開くたびに計算して表示するだけ（記録作業を増やさない）。
/// - 3つの選択枠は独立して「ブランド → シリーズ → テープ/パンツ」を持つ
///   （自宅＝パンツ・預け先＝テープのような併用に対応）。
/// - ブランドのロゴ・色分けは使わない（テキスト表記のみ）。
/// - 体型からの推薦・断定はしない。子どもの体や年齢の評価は一切出さない。
///
/// 背景は AppShell が敷くテーマ淡色をそのまま活かす（Scaffold は持たない）。
class DiaperGuideView extends StatefulWidget {
  const DiaperGuideView({
    super.key,
    required this.child,
    required this.onUpdateChild,
  });

  final ChildProfile child;
  final ValueChanged<ChildProfile> onUpdateChild;

  @override
  State<DiaperGuideView> createState() => _DiaperGuideViewState();
}

class _DiaperGuideViewState extends State<DiaperGuideView> {
  static const _titleColor = Color(0xFF1A1A1A);

  /// 選択枠の数（固定3つ。1〜2枠だけの利用でも動作する）。
  static const int _slotCount = 3;

  /// 非表示の提案カードを表示中か（この画面を開いた時点で1回だけ判定）。
  bool _showHideSuggestion = false;

  ChildProfile get _child => widget.child;

  /// バッジの男児色・女児色の出し分けに使う（トレパンマン等）。
  bool get _isBoy => _child.gender == Gender.male;

  @override
  void initState() {
    super.initState();
    // 提案判定は「開いた時点」のデータで行い、その後に開いた記録を更新する
    // （先に更新すると「3か月開いていない」が常に不成立になるため順序が重要）。
    _showHideSuggestion = shouldSuggestHidingDiaperGuide(_child);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final last = _child.diaperGuideLastOpenedAt;
      final sameDay = last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
      if (sameDay && !_showHideSuggestion) return;
      widget.onUpdateChild(
        _child.copyWith(
          diaperGuideLastOpenedAt: now,
          // 提案を出した事実を記録（「あとで」後の再提案抑制に使う）。
          diaperGuideHideSuggestedAt: _showHideSuggestion ? now : null,
        ),
      );
    });
  }

  // ── 選択枠の読み書き ────────────────────────────────────────────────────

  DiaperSlot? _slotAt(int index) {
    for (final s in _child.diaperSlots) {
      if (s.slotIndex == index) return s;
    }
    return null;
  }

  void _setSlot(int index, DiaperSeries series, DiaperType type) {
    final slots = [..._child.diaperSlots]
      ..removeWhere((s) => s.slotIndex == index)
      ..add(DiaperSlot(slotIndex: index, seriesId: series.id, type: type))
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    widget.onUpdateChild(_child.copyWith(diaperSlots: slots));
  }

  void _clearSlot(int index) {
    widget.onUpdateChild(
      _child.copyWith(
        diaperSlots: [..._child.diaperSlots]
          ..removeWhere((s) => s.slotIndex == index),
      ),
    );
  }

  /// 同じ「シリーズ×タイプ」が他の枠で選択済みか。
  /// （同じシリーズでもタイプが違えば重複ではない。）
  bool _isUsedByOtherSlot(int index, String seriesId, DiaperType type) =>
      _child.diaperSlots.any(
        (s) => s.slotIndex != index && s.seriesId == seriesId && s.type == type,
      );

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latestWeight = latestWeightRecord(_child.growthRecords);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_showHideSuggestion) ...[
              _buildHideSuggestionCard(scheme),
              const SizedBox(height: 10),
            ],
            // 洋服ガイドと同じ構成：体重記録があれば「現在の体重＋成長
            // トレンド」のサマリー、無ければ記録を促す案内カード。
            if (latestWeight != null)
              _buildSummaryCard(latestWeight)
            else
              _buildNoWeightNotice(scheme),
            const SizedBox(height: 10),
            if (latestWeight != null && _allSelectedSlotsAboveRange()) ...[
              _buildAllAboveRangeNotice(scheme),
              const SizedBox(height: 10),
            ],
            for (var i = 0; i < _slotCount; i++) ...[
              _buildSlotCard(scheme, i, latestWeight),
              const SizedBox(height: 10),
            ],
            if (latestWeight != null && _child.diaperSlots.isNotEmpty) ...[
              const SizedBox(height: 2),
              _buildWeightSourceNote(latestWeight),
            ],
            const SizedBox(height: 6),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  /// 洋服ガイドのサマリーカードと同じ見た目で「現在の体重・成長トレンド」
  /// を出す（洋服側は身長ベース、こちらは体重ベース）。共通ウィジェット
  /// [GuideSummaryCard] を使うことで、片方だけ直して見た目がずれることを
  /// 防ぐ（変更依頼2・§8）。
  Widget _buildSummaryCard(GrowthRecord latestWeight) {
    final baselineSd = computeWeightBaselineSd(_child);
    return GuideSummaryCard(
      primaryLabel: '現在の体重',
      primaryValue: '${formatWeightKg(latestWeight.weightKg!)} kg',
      trendLabel: '成長トレンド',
      trendValue:
          baselineSd != null ? formatBaselineSdScoreValue(baselineSd) : '—',
    );
  }

  /// 体重記録が1件も無いときの案内（靴ガイドの空状態と同じ構成で、
  /// どこで記録すればよいかまで具体的に示す）。
  Widget _buildNoWeightNotice(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          PhosphorIcon(
            PhosphorIconsDuotone.baby,
            color: scheme.primary,
            size: 40,
            duotoneSecondaryColor: scheme.primary.withValues(alpha: 0.45),
            duotoneSecondaryOpacity: 1,
          ),
          const SizedBox(height: 10),
          Text(
            'サイズの表示には体重の記録が必要です。\n'
            'グラフ画面の＋ボタンから体重を1回以上登録してください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// 計算に使った体重記録の明示（事実の透明性のため）。
  Widget _buildWeightSourceNote(GrowthRecord record) {
    final d = record.date;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '体重 ${formatWeightKg(record.weightKg!)}kg'
        '（${d.year}/${d.month}/${d.day} 記録）をもとに表示しています',
        style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
      ),
    );
  }

  // ── 選択枠カード ────────────────────────────────────────────────────────

  Widget _buildSlotCard(
    ColorScheme scheme,
    int index,
    GrowthRecord? latestWeight,
  ) {
    final slot = _slotAt(index);
    if (slot == null) return _buildEmptySlotCard(scheme, index);

    final series = findDiaperSeriesById(kDiaperBrands, slot.seriesId);
    final brand =
        series == null ? null : findDiaperBrandById(kDiaperBrands, series.brandId);
    // マスタ更新などで参照先が見つからない場合は選び直しを促す。
    if (series == null || brand == null) {
      return _buildBrokenSlotCard(scheme, index);
    }

    final guide = computeDiaperSlotGuide(
      child: _child,
      ladder: series.bandsFor(slot.type),
    );

    return DiaperSlotSummaryCard(
      series: series,
      type: slot.type,
      isBoy: _isBoy,
      guide: guide,
      onTap: () => _openSlotDialog(index),
    );
  }

  // ── 最大サイズ超え（§4-9(c)） ──────────────────────────────────────────

  /// §4-9(d)：選択中のすべての枠で上限を超えている場合の案内。
  bool _allSelectedSlotsAboveRange() {
    final weight = latestWeightRecord(_child.growthRecords)?.weightKg;
    if (weight == null) return false;

    var validSlots = 0;
    for (final slot in _child.diaperSlots) {
      final series = findDiaperSeriesById(kDiaperBrands, slot.seriesId);
      if (series == null) continue;
      final ladder = series.bandsFor(slot.type);
      if (ladder.isEmpty) continue;
      validSlots++;
      if (evaluateDiaperFit(ladder: ladder, weightKg: weight).status !=
          DiaperFitStatus.aboveRange) {
        return false;
      }
    }
    return validSlots > 0;
  }

  Widget _buildAllAboveRangeNotice(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Text(
        '選択中のおむつでは、対応するサイズが見つかりませんでした。'
        '各カードをタップすると選び直せます',
        style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey[700]),
      ),
    );
  }

  // ── 非表示の提案（§4-10。行動ベースのみ。「卒業」とは言わない） ─────────

  Widget _buildHideSuggestionCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近おむつガイドを開いていないようです。非表示にしますか？\n'
            '（お子さまの編集画面からいつでも戻せます）',
            style: TextStyle(fontSize: 12, height: 1.6, color: Colors.grey[800]),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showHideSuggestion = false),
                child: const Text('あとで', style: TextStyle(fontSize: 12.5)),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  // 提案からOFFへ1タップ（タブ自体が消える）。
                  widget.onUpdateChild(
                    _child.copyWith(diaperGuideEnabled: false),
                  );
                },
                child: const Text(
                  '非表示にする',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 小さな表示部品 ──────────────────────────────────────────────────────

  /// 未選択の枠：選択を促すカード。
  Widget _buildEmptySlotCard(ColorScheme scheme, int index) {
    return Material(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openSlotDialog(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '比較したいおむつを選んでください',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(scheme.primary, Colors.black, 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 参照先のマスタが見つからない枠（通常は起きない）。選び直しを促す。
  Widget _buildBrokenSlotCard(ColorScheme scheme, int index) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openSlotDialog(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Text(
            'このおむつの情報が見つかりませんでした。タップして選び直してください',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  // ── 注記 ────────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '※本アプリは各おむつメーカーと提携関係にありません。\n'
        '※体重のめやすは各社が公表している値にもとづく目安です。'
        '実際のフィット感はお子様の体型により異なります。\n'
        '※紙おむつが対象です（布おむつは対象外）。',
        style: TextStyle(fontSize: 10.5, height: 1.6, color: Colors.grey[600]),
      ),
    );
  }

  // ── 選択ダイアログ（ブランド → シリーズ → タイプ） ─────────────────────
  //
  // 靴の記録や身長体重の入力と同じく、画面中央のダイアログで選択する
  // （ボトムシートより手元で選びやすい、という UI の一貫性のため）。

  Future<void> _openSlotDialog(int slotIndex) async {
    final existing = _slotAt(slotIndex);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        // ダイアログ内のウィザード状態（ブランド → シリーズ → タイプ）。
        DiaperBrand? pickedBrand;
        DiaperSeries? pickedSeries; // 両タイプ持ちでタイプ選択待ちのときだけ非null

        return StatefulBuilder(
          builder: (ctx, setS) {
            void confirm(DiaperSeries series, DiaperType type) {
              // UI側で無効化しているが、念のため二重チェック。
              if (_isUsedByOtherSlot(slotIndex, series.id, type)) return;
              _setSlot(slotIndex, series, type);
              Navigator.of(dialogCtx).pop();
            }

            final String title;
            final List<Widget> body;
            if (pickedBrand == null) {
              // ── 1段目：ブランド一覧（法人名は出さない）──
              title = 'ブランドを選択';
              body = [
                for (final brand in kDiaperBrands)
                  ListTile(
                    title: Text(
                      brand.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => setS(() => pickedBrand = brand),
                  ),
                if (existing != null) ...[
                  const Divider(height: 12, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: Colors.red[300],
                    ),
                    title: Text(
                      'この枠の選択を解除',
                      style: TextStyle(fontSize: 13.5, color: Colors.red[400]),
                    ),
                    onTap: () {
                      _clearSlot(slotIndex);
                      Navigator.of(dialogCtx).pop();
                    },
                  ),
                ],
              ];
            } else if (pickedSeries == null) {
              // ── 2段目：シリーズ一覧（シリーズ名のみ表示）──
              final brand = pickedBrand!;
              title = '${brand.displayName} のシリーズを選択';
              body = [
                _dialogBackRow(
                  label: 'ブランド選択に戻る',
                  onTap: () => setS(() => pickedBrand = null),
                ),
                for (final series in brand.series)
                  _buildSeriesTile(
                    series: series,
                    slotIndex: slotIndex,
                    onNeedType: () => setS(() => pickedSeries = series),
                    onConfirm: confirm,
                  ),
              ];
            } else {
              // ── 3段目：タイプ選択（両タイプ持ちの8シリーズのみ到達）──
              final series = pickedSeries!;
              title = '${series.displayName} のタイプを選択';
              body = [
                _dialogBackRow(
                  label: 'シリーズ選択に戻る',
                  onTap: () => setS(() => pickedSeries = null),
                ),
                for (final type in series.availableTypes)
                  _buildTypeTile(
                    series: series,
                    type: type,
                    slotIndex: slotIndex,
                    onConfirm: confirm,
                  ),
              ];
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              // 行を端まで使えるよう左右パディングは持たせない
              // （ListTile 側の余白で揃える）。
              contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: body,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('キャンセル'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// シリーズ1行分。タイプが1つだけのシリーズはタイプ選択をスキップして
  /// そのタイプで確定する（1択の画面を出さない。これが主要な経路）。
  Widget _buildSeriesTile({
    required DiaperSeries series,
    required int slotIndex,
    required VoidCallback onNeedType,
    required void Function(DiaperSeries, DiaperType) onConfirm,
  }) {
    final types = series.availableTypes;
    final bool needsTypeChoice = series.hasBothTypes;

    // 選択可能なタイプが全部他の枠で使用済みなら行ごと無効化する。
    final freeTypes = [
      for (final t in types)
        if (!_isUsedByOtherSlot(slotIndex, series.id, t)) t,
    ];
    final enabled = freeTypes.isNotEmpty;

    // 片タイプのみのシリーズはタイプ名を添えて内容を明確にする。
    final subtitle = needsTypeChoice
        ? 'テープ / パンツ'
        : '${diaperTypeLabel(types.single)}タイプ';

    return ListTile(
      enabled: enabled,
      // シリーズ識別バッジ。タイプ未確定（両タイプ持ち）の行はベース色で出す。
      leading: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: DiaperBadge(
          series: series,
          type: needsTypeChoice ? null : types.single,
          isBoy: _isBoy,
          size: 32,
        ),
      ),
      title: Text(
        series.displayName,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        enabled ? subtitle : '別の枠で選択済み',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      trailing: needsTypeChoice
          ? const Icon(Icons.chevron_right_rounded, size: 20)
          : null,
      onTap: !enabled
          ? null
          : () {
              if (needsTypeChoice) {
                onNeedType();
              } else {
                onConfirm(series, types.single);
              }
            },
    );
  }

  /// タイプ1行分（テープ / パンツ）。タイプで商品名が変わるシリーズは
  /// 選んだタイプの商品名を添える（例：ムーニーのパンツ→ムーニーマン）。
  Widget _buildTypeTile({
    required DiaperSeries series,
    required DiaperType type,
    required int slotIndex,
    required void Function(DiaperSeries, DiaperType) onConfirm,
  }) {
    final used = _isUsedByOtherSlot(slotIndex, series.id, type);
    final resolvedName = series.seriesNameFor(type);
    final showsProductName = resolvedName != series.displayName;

    return ListTile(
      enabled: !used,
      title: Text(
        diaperTypeLabel(type),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        used
            ? '別の枠で選択済み'
            : showsProductName
                ? '商品名：$resolvedName'
                : ' ',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      onTap: used ? null : () => onConfirm(series, type),
    );
  }

  Widget _dialogBackRow({required String label, required VoidCallback onTap}) =>
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      );
}
