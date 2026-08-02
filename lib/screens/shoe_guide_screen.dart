import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/adaptive_layout.dart';
import '../growth/clothing_size_guide.dart';
import '../models/child_profile.dart';
import '../models/shoe_records.dart';
import '../monetization/pro_status.dart';
import '../widgets/footprint_icon.dart';
import '../widgets/pro_gate.dart';
import '../widgets/shoe_forecast_steps.dart';

/// 履歴一覧の絞り込み。
enum _HistoryFilter { all, measurement, purchase }

/// 靴の記録・予測ビュー（洋服ガイドタブ内の「靴ガイド」表示）。
///
/// 足長の実測と靴の購入サイズを記録し、成長トレンドから
/// 「今の靴がいつまで履けるか」「次に買うサイズと時期」を予測する。
/// 背景は AppShell が敷くテーマ淡色をそのまま活かす（Scaffold は持たない）。
class ShoeGuideView extends StatefulWidget {
  const ShoeGuideView({
    super.key,
    required this.child,
    required this.onUpdateChild,
  });

  final ChildProfile child;
  final ValueChanged<ChildProfile> onUpdateChild;

  @override
  State<ShoeGuideView> createState() => _ShoeGuideViewState();
}

class _ShoeGuideViewState extends State<ShoeGuideView> {
  static const _staleColor = Color(0xFFB25E09);
  static const _purchaseColor = Color(0xFF3679A8); // 購入（買い物）

  _HistoryFilter _filter = _HistoryFilter.all;

  ChildProfile get _child => widget.child;

  // ── 記録の追加・編集・削除 ──────────────────────────────────────────────

  void _addMeasurement(DateTime date, double footLengthCm) {
    widget.onUpdateChild(
      _child.copyWith(
        footMeasurements: [
          ..._child.footMeasurements,
          FootMeasurement(date: date, footLengthCm: footLengthCm),
        ],
      ),
    );
  }

  void _addPurchase(DateTime date, double sizeCm) {
    widget.onUpdateChild(
      _child.copyWith(
        shoePurchases: [
          ..._child.shoePurchases,
          ShoePurchase(date: date, sizeCm: sizeCm),
        ],
      ),
    );
  }

  void _replaceMeasurement(FootMeasurement old, DateTime date, double value) {
    final list = [..._child.footMeasurements];
    final i = list.indexOf(old);
    if (i < 0) return;
    list[i] = FootMeasurement(date: date, footLengthCm: value);
    widget.onUpdateChild(_child.copyWith(footMeasurements: list));
  }

  void _replacePurchase(ShoePurchase old, DateTime date, double value) {
    final list = [..._child.shoePurchases];
    final i = list.indexOf(old);
    if (i < 0) return;
    list[i] = ShoePurchase(date: date, sizeCm: value);
    widget.onUpdateChild(_child.copyWith(shoePurchases: list));
  }

  void _removeMeasurement(FootMeasurement m) {
    widget.onUpdateChild(
      _child.copyWith(
        footMeasurements: [..._child.footMeasurements]..remove(m),
      ),
    );
  }

  void _removePurchase(ShoePurchase p) {
    widget.onUpdateChild(
      _child.copyWith(shoePurchases: [..._child.shoePurchases]..remove(p)),
    );
  }

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = computeShoeSizePurchasePlan(_child);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _buildForecastCard(scheme, plan),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showMeasurementDialog(),
                    icon: const FootprintIcon(size: 18),
                    label: const Text('足長を記録'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPurchaseDialog(),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('購入を記録'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildHistorySection(scheme),
          ],
        ),
      ),
    );
  }

  // ── 予測カード ──────────────────────────────────────────────────────────

  Widget _buildForecastCard(ColorScheme scheme, ShoeSizePurchasePlan? plan) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: plan == null
          ? _buildEmptyForecast(scheme)
          : _buildForecastBody(scheme, plan),
    );
  }

  Widget _buildEmptyForecast(ColorScheme scheme) {
    // 実測はあるのに予測できない場合、原因は身長記録の不足。
    // 「測ってください」だけでは伝わらないので案内を出し分ける。
    final hasMeasurement = _child.footMeasurements.isNotEmpty;
    final message = hasMeasurement
        ? '予測には身長の記録も必要です。\n'
              'グラフ画面の＋ボタンから身長を1回以上登録してください。'
        : 'まずは足長（かかと〜つま先）をメジャーなどで測って記録してください。\n'
              '成長トレンドとあわせて、次に買うサイズと時期を予測します。';
    return Column(
      children: [
        PhosphorIcon(
          PhosphorIconsDuotone.sneaker,
          color: scheme.primary,
          size: 40,
          duotoneSecondaryColor: scheme.primary.withValues(alpha: 0.45),
          duotoneSecondaryOpacity: 1,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastBody(ColorScheme scheme, ShoeSizePurchasePlan plan) {
    final staleDays = DateTime.now().difference(plan.measuredAt).inDays;
    final isStale = staleDays >= shoeMeasurementStaleDays;
    final lastPurchase = plan.lastPurchase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 書き出し画像と同じ3列サマリー（実測足長 → いまの目安 ｜ いまの靴）。
        ShoeMetricsCard(plan: plan),
        // 「警告 → 📍いま → 次の購入 → その先」のステップ表示。
        // 書き出し画像（サイズガイド）と同じ部品・同じ構成にそろえる。
        // 無料版：警告と「いま」行までは表示し、先読み行はぼかし＋鍵。
        ValueListenableBuilder<bool>(
          valueListenable: ProStatus.isPro,
          builder: (context, isPro, _) {
            final forecastRows = ShoeForecastStepRows(plan: plan);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                if (plan.currentShoeOutgrown) ...[
                  ShoeOutgrownBanner(
                    lastPurchaseSizeCm: lastPurchase?.sizeCm,
                  ),
                  const SizedBox(height: 8),
                ],
                ShoeCurrentStepRow(plan: plan),
                if (isPro)
                  forecastRows
                else
                  ProGate(
                    lockLabel: '購入時期の先読みはPro版で',
                    child: forecastRows,
                  ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
        Row(
          children: [
            if (isStale) ...[
              const Icon(Icons.error_outline, size: 13, color: _staleColor),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(
                // 実測値・測定日はサマリーカードに出したので、ここでは
                // 経過と計算の前提だけを補足する。
                isStale
                    ? '実測 ${plan.measuredFootLengthCm.toStringAsFixed(1)}cm は'
                          '${_elapsedLabel(staleDays)}前のものです。'
                          '再測定をおすすめします'
                    : '実測（${_elapsedLabel(staleDays)}前）からの成長ぶんと、'
                          'つま先余裕+${shoeToeAllowanceCm.toStringAsFixed(1)}cm'
                          'を見込んだ目安です',
                style: TextStyle(
                  fontSize: 10,
                  color: isStale ? _staleColor : Colors.grey[500],
                  fontWeight: isStale ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 記録履歴 ────────────────────────────────────────────────────────────

  Widget _buildHistorySection(ColorScheme scheme) {
    // 実測と購入を1つの時系列（新しい順）にまとめ、フィルタを適用する。
    final items = <({DateTime date, bool isPurchase, Object record})>[
      if (_filter != _HistoryFilter.purchase)
        for (final m in _child.footMeasurements)
          (date: m.date, isPurchase: false, record: m),
      if (_filter != _HistoryFilter.measurement)
        for (final p in _child.shoePurchases)
          (date: p.date, isPurchase: true, record: p),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final hasAnyRecord =
        _child.footMeasurements.isNotEmpty || _child.shoePurchases.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'これまでの記録',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const Spacer(),
            _buildFilterSegment(scheme),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Text(
              hasAnyRecord ? '該当する記録がありません' : 'まだ記録がありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0.5,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _historyTile(items[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterSegment(ColorScheme scheme) {
    return SegmentedButton<_HistoryFilter>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        selectedBackgroundColor: scheme.primary.withValues(alpha: 0.16),
        selectedForegroundColor: scheme.primary,
        foregroundColor: Colors.grey[700],
      ),
      segments: const [
        ButtonSegment(value: _HistoryFilter.all, label: Text('すべて')),
        ButtonSegment(value: _HistoryFilter.measurement, label: Text('実測')),
        ButtonSegment(value: _HistoryFilter.purchase, label: Text('購入')),
      ],
      selected: {_filter},
      onSelectionChanged: (s) => setState(() => _filter = s.first),
    );
  }

  Widget _historyTile(({DateTime date, bool isPurchase, Object record}) item) {
    final isPurchase = item.isPurchase;
    final valueText = isPurchase
        ? '購入 ${(item.record as ShoePurchase).sizeCm.toStringAsFixed(1)}cm'
        : '足長 ${(item.record as FootMeasurement).footLengthCm.toStringAsFixed(1)}cm';

    return ListTile(
      dense: true,
      onTap: () => _editRecord(item),
      leading: isPurchase
          ? const Icon(
              Icons.shopping_bag_outlined,
              size: 20,
              color: _purchaseColor,
            )
          : const FootprintIcon(size: 20),
      title: Text(
        valueText,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_formatDate(item.date)}・タップで編集',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 19, color: Colors.grey[500]),
        tooltip: '削除',
        onPressed: () => _confirmDelete(item),
      ),
    );
  }

  void _editRecord(({DateTime date, bool isPurchase, Object record}) item) {
    if (item.isPurchase) {
      final p = item.record as ShoePurchase;
      _showValueDateDialog(
        title: '購入記録を編集',
        description: '購入した靴のサイズと日付を修正できます。',
        dateLabel: '購入日',
        stepCm: _purchaseStepCm,
        minCm: _purchaseMinCm,
        maxCm: _shoeMaxCm,
        initialValue: p.sizeCm,
        initialDate: p.date,
        onSave: (date, v) => _replacePurchase(p, date, v),
      );
    } else {
      final m = item.record as FootMeasurement;
      _showValueDateDialog(
        title: '実測記録を編集',
        description: '実測した足長と日付を修正できます。',
        dateLabel: '測定日',
        stepCm: _measureStepCm,
        minCm: _measureMinCm,
        maxCm: _shoeMaxCm,
        initialValue: m.footLengthCm,
        initialDate: m.date,
        onSave: (date, v) => _replaceMeasurement(m, date, v),
      );
    }
  }

  Future<void> _confirmDelete(
    ({DateTime date, bool isPurchase, Object record}) item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '記録を削除',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${_formatDate(item.date)} の'
          '${item.isPurchase ? '購入記録' : '足長の実測'}を削除しますか？',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (item.isPurchase) {
      _removePurchase(item.record as ShoePurchase);
    } else {
      _removeMeasurement(item.record as FootMeasurement);
    }
  }

  // ── 入力ダイアログ ──────────────────────────────────────────────────────

  /// 足長の実測は 0.1cm 刻み、靴の購入サイズは市販の展開に合わせ 0.5cm 刻み。
  static const double _measureStepCm = 0.1;
  static const double _purchaseStepCm = 0.5;
  static const double _measureMinCm = 6.0;
  static const double _purchaseMinCm = 8.0;
  static const double _shoeMaxCm = 30.0;

  Future<void> _showMeasurementDialog() => _showValueDateDialog(
        title: '足長を記録',
        description: 'かかとからつま先までの長さ（足長）を測って記録します。',
        dateLabel: '測定日',
        stepCm: _measureStepCm,
        minCm: _measureMinCm,
        maxCm: _shoeMaxCm,
        initialValue: latestFootMeasurement(_child)?.footLengthCm ?? 13.0,
        onSave: _addMeasurement,
      );

  Future<void> _showPurchaseDialog() {
    // Pro版では「次の購入」でおすすめしているサイズを初期値にする
    // （買い替えのタイミングで記録するのが典型的な使い方のため）。
    // 無料版では先読みサイズが漏れないよう「いまの目安」までにとどめる。
    final plan = computeShoeSizePurchasePlan(_child);
    final nextSize = ProStatus.isPro.value ? plan?.nextPurchase?.shoeSizeCm : null;
    return _showValueDateDialog(
      title: '購入を記録',
      description: '購入した靴のサイズを記録します。',
      dateLabel: '購入日',
      stepCm: _purchaseStepCm,
      minCm: _purchaseMinCm,
      maxCm: _shoeMaxCm,
      initialValue: nextSize ??
          plan?.currentShoeSizeCm ??
          latestShoePurchase(_child)?.sizeCm ??
          14.0,
      onSave: _addPurchase,
    );
  }

  /// 日付＋数値の入力ダイアログ。成長記録の入力と同じく「日付が上、
  /// 数値が下」の並びで、数値は回して選ぶホイール式（[stepCm] 刻み）。
  Future<void> _showValueDateDialog({
    required String title,
    required String description,
    required String dateLabel,
    required double stepCm,
    required double minCm,
    required double maxCm,
    required double? initialValue,
    DateTime? initialDate,
    required void Function(DateTime date, double valueCm) onSave,
  }) async {
    final itemCount = ((maxCm - minCm) / stepCm).round() + 1;
    double valueAt(int i) => minCm + i * stepCm;
    int indexOf(double v) =>
        ((v - minCm) / stepCm).round().clamp(0, itemCount - 1);

    var index = indexOf(initialValue ?? (minCm + maxCm) / 2);
    var date = initialDate ?? DateTime.now();
    final wheelCtrl = FixedExtentScrollController(initialItem: index);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: date,
                    firstDate: _child.birthDate,
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => date = picked);
                  }
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  '$dateLabel: ${_formatDate(date)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  height: 130,
                  width: 160,
                  child: CupertinoPicker.builder(
                    itemExtent: 34,
                    scrollController: wheelCtrl,
                    onSelectedItemChanged: (i) => index = i,
                    childCount: itemCount,
                    itemBuilder: (_, i) => Center(
                      child: Text(
                        '${valueAt(i).toStringAsFixed(1)} cm',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                onSave(date, valueAt(index));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    wheelCtrl.dispose();
  }

  // ── 表示ヘルパー ────────────────────────────────────────────────────────

  static String _formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

  static String _elapsedLabel(int days) {
    if (days <= 0) return '本日';
    if (days < 31) return '$days日';
    return '${days ~/ 30}ヶ月';
  }
}
