import 'package:flutter/material.dart';

import '../growth/growth_period_summary.dart';
import '../models/child_profile.dart';

Color _positiveColor() => Colors.blue[700]!;
Color _negativeColor() => Colors.red[600]!;

Color _deltaColor(double delta) =>
    delta >= 0 ? _positiveColor() : _negativeColor();

/// 身長の伸び（例：`+ 8.5 cm`）。
String _formatDeltaCm(double delta) {
  if (delta >= 0) return '+ ${delta.toStringAsFixed(1)} cm';
  return '${delta.toStringAsFixed(1)} cm';
}

/// SD差分（例：`+1.3` / `-0.2`）。先頭表示用。
String _formatSdDeltaPlain(double delta) {
  final s = delta.abs().toStringAsFixed(1);
  if (delta >= 0) return '+$s';
  return '-$s';
}

/// SD推移の元数値（例：`-1.8 ➔ -0.5`）。
String _formatSdRange(double sdStart, double sdEnd) {
  String value(double sd) {
    if (sd >= 0) return '+${sd.toStringAsFixed(1)}';
    return sd.toStringAsFixed(1);
  }

  return '${value(sdStart)} ➔ ${value(sdEnd)}';
}

/// 年間ペース・SDスコア行の計算結果（ラベルより大きく強調）。
const _kMetricValueStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

/// 左ラベル列（ラベル文字・コロンを固定幅で整列、コロン前後に余白）。
class _MetricLabel extends StatelessWidget {
  const _MetricLabel(this.text);

  final String text;

  static const _textWidth = 116.0;
  static const _gapBeforeColon = 4.0;
  static const _colonWidth = 10.0;
  static const valueGap = 8.0;

  static const _style = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1A1A1A),
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: _textWidth,
          child: Text(
            text,
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: _style,
          ),
        ),
        const SizedBox(width: _gapBeforeColon),
        const SizedBox(
          width: _colonWidth,
          child: Text('：', style: _style),
        ),
      ],
    );
  }
}

/// 成長ペースダイアログを閉じた際のアクション。
enum GrowthSummaryDialogResult {
  /// × または背景タップで閉じた（比較・選択を終了）。
  dismissed,

  /// 「別の期間を選択」で閉じた（リストの選択モードへ戻る）。
  pickAnotherPeriod,
}

/// 成長ペースサマリーを中央ダイアログで表示する（共通）。
Future<GrowthSummaryDialogResult?> showGrowthSummaryDialog({
  required BuildContext context,
  required ChildProfile child,
  required GrowthPeriodSummary summary,
  required String blockTitle,
}) {
  return showDialog<GrowthSummaryDialogResult>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogCtx) {
      final maxHeight = MediaQuery.sizeOf(dialogCtx).height * 0.85;
      final outlineStyle = OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        side: BorderSide(color: Colors.grey[400]!),
        foregroundColor: Colors.grey[800],
      );

      void closeDismissed() {
        Navigator.pop(dialogCtx, GrowthSummaryDialogResult.dismissed);
      }

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GrowthSummaryHeader(child: child),
                    const SizedBox(height: 24),
                    _SummaryBlock(
                      title: blockTitle,
                      summary: summary,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        dialogCtx,
                        GrowthSummaryDialogResult.pickAnotherPeriod,
                      ),
                      icon: const Text('🔍', style: TextStyle(fontSize: 16)),
                      label: const Text('別の期間を選択'),
                      style: outlineStyle,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: closeDismissed,
                  icon: Icon(Icons.close, color: Colors.grey[700]),
                  tooltip: '閉じる',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 直近1年の成長ペースサマリーを中央ダイアログで表示する。
Future<GrowthSummaryDialogResult?> showGrowthSummarySheet({
  required BuildContext context,
  required ChildProfile child,
}) {
  final summary = GrowthPeriodSummaryCalculator.lastYear(
    child: child,
    records: child.growthRecords,
  );

  return showGrowthSummaryDialog(
    context: context,
    child: child,
    summary: summary,
    blockTitle: '直近の成長ペース',
  );
}

/// ユーザーが選択した2記録の比較結果を中央ダイアログで表示する。
Future<GrowthSummaryDialogResult?> showGrowthComparisonSummarySheet({
  required BuildContext context,
  required ChildProfile child,
  required GrowthPeriodSummary summary,
}) {
  return showGrowthSummaryDialog(
    context: context,
    child: child,
    summary: summary,
    blockTitle: '選択した期間の成長ペース',
  );
}

class _GrowthSummaryHeader extends StatelessWidget {
  const _GrowthSummaryHeader({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            '📈 ${child.displayName} の成長ペース',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '身長データから自動計算（体重は含みません）',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.title,
    required this.summary,
  });

  final String title;
  final GrowthPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          if (!summary.hasData)
            Text(
              'データ不足のため計算できません',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            )
          else
            _SummaryContent(summary: summary),
        ],
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final GrowthPeriodSummary summary;

  static const _bodyTextColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final start = summary.start!;
    final end = summary.end!;
    final delta = summary.heightDeltaCm!;
    final startH = start.heightCm!;
    final endH = end.heightCm!;
    final deltaColor = _deltaColor(delta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ① 期間（1行に収めるため FittedBox で自動縮小）
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            summary.dateRangeLabel ?? '',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ② 伸び幅 ＋ ③ 元数値を横並び（baseline 揃え・中央配置）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatDeltaCm(delta),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: deltaColor,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${startH.toStringAsFixed(1)} cm ➔ ${endH.toStringAsFixed(1)} cm',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ④ 年間成長ペース
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const _MetricLabel('年間ペース'),
            const SizedBox(width: _MetricLabel.valueGap),
            Text(
              '${summary.cmPerYear!.toStringAsFixed(1)} cm',
              style: _kMetricValueStyle.copyWith(color: _bodyTextColor),
            ),
          ],
        ),
        if (summary.sdStart != null && summary.sdEnd != null) ...[
          const SizedBox(height: 8),
          // ⑤ SD推移：差分 ➔ 元数値（身長行と同じ並び）
          _SdTransitionRow(
            sdStart: summary.sdStart!,
            sdEnd: summary.sdEnd!,
          ),
        ],
      ],
    );
  }
}

class _SdTransitionRow extends StatelessWidget {
  const _SdTransitionRow({
    required this.sdStart,
    required this.sdEnd,
  });

  final double sdStart;
  final double sdEnd;

  @override
  Widget build(BuildContext context) {
    final sdDelta = sdEnd - sdStart;
    final deltaColor = _deltaColor(sdDelta);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const _MetricLabel('SDスコア'),
        const SizedBox(width: _MetricLabel.valueGap),
        Text(
          _formatSdDeltaPlain(sdDelta),
          style: _kMetricValueStyle.copyWith(color: deltaColor),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatSdRange(sdStart, sdEnd),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
