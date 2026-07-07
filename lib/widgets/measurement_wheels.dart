// 身長・体重のホイール入力の仕様（値域・刻み・表示）。
// 成長記録の入力フォームと、お誕生日の思い出の入力で共通に使う。
import 'package:flutter/cupertino.dart'
    show
        CupertinoPicker,
        CupertinoPickerDefaultSelectionOverlay,
        FixedExtentScrollController;
import 'package:flutter/material.dart';

// 身長：20.0〜199.9cm を 0.1cm 刻み（超早産児にも対応）。
const _hMinTenths = 200; // 20.0cm
const _hMaxTenths = 1999; // 199.9cm

// 体重：0.10〜9.99kg は 10g 刻み（母子手帳が g 表記の乳児期用）、
// 10.0〜99.9kg は 100g 刻み。単位は centi-kg（0.01kg）で持つ。
const _wMinCenti = 10; // 0.10kg
const _wFineMaxCenti = 999; // 9.99kg（ここまで 10g 刻み）
const _wCoarseMinCenti = 1000; // 10.0kg（ここから 100g 刻み）
const _wMaxCenti = 9990; // 99.9kg
const _wFineCount = _wFineMaxCenti - _wMinCenti + 1; // 10g 刻みの項目数

/// 身長ホイールの項目数。
const int heightWheelItemCount = _hMaxTenths - _hMinTenths + 1;

/// 体重ホイールの項目数。
const int weightWheelItemCount =
    _wFineCount + (_wMaxCenti - _wCoarseMinCenti) ~/ 10 + 1;

/// g 換算の併記を出す上限。乳児期（母子手帳が g 表記の時期）に相当する。
const double weightGramNoteMaxKg = 10.0;

/// 体重ホイールの index → centi-kg 値。
int weightCentiAtWheelIndex(int index) => index < _wFineCount
    ? _wMinCenti + index
    : _wCoarseMinCenti + (index - _wFineCount) * 10;

/// 体重ホイールの index → kg 値。
double weightKgAtWheelIndex(int index) => weightCentiAtWheelIndex(index) / 100;

/// kg 値 → 体重ホイールの index（範囲外はクランプ）。
int weightWheelIndexOf(double kg) {
  var centi = (kg * 100).round().clamp(_wMinCenti, _wMaxCenti);
  if (centi <= _wFineMaxCenti) return centi - _wMinCenti;
  centi = (centi ~/ 10) * 10;
  return _wFineCount + (centi - _wCoarseMinCenti) ~/ 10;
}

/// 体重ホイールの表示ラベル（10g 刻み帯は小数2桁、100g 刻み帯は1桁）。
String weightWheelLabelAt(int index) {
  final centi = weightCentiAtWheelIndex(index);
  return centi <= _wFineMaxCenti
      ? (centi / 100).toStringAsFixed(2)
      : (centi / 100).toStringAsFixed(1);
}

/// 身長ホイールの index → cm 値。
double heightCmAtWheelIndex(int index) => (_hMinTenths + index) / 10.0;

/// cm 値 → 身長ホイールの index（範囲外はクランプ）。
int heightWheelIndexOf(double cm) =>
    (cm * 10).round().clamp(_hMinTenths, _hMaxTenths) - _hMinTenths;

/// 身長ホイールの表示ラベル。
String heightWheelLabelAt(int index) =>
    heightCmAtWheelIndex(index).toStringAsFixed(1);

/// 数値そのものをスクロールする 1 本のホイール。
/// 項目数が多い（〜2800件）ため builder で遅延生成する。
class MeasurementValueWheel extends StatelessWidget {
  const MeasurementValueWheel({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.labelAt,
    required this.onChanged,
    this.scale = 1.0,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelAt;
  final void Function(int index) onChanged;

  /// 大画面用の拡大率（最大1.3倍）。
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = scale;
    return SizedBox(
      width: 92 * s,
      height: 140 * s,
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 36 * s,
        childCount: itemCount,
        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
          capStartEdge: false,
          capEndEdge: false,
        ),
        onSelectedItemChanged: onChanged,
        itemBuilder: (context, i) => Center(
          child: Text(
            labelAt(i),
            style: TextStyle(
              fontSize: 22 * s,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// ラベル＋単位＋「記録する/しない」トグル付きのホイール枠。
/// OFF のときは薄く表示して操作を無効化する。
class MeasurementPickerColumn extends StatelessWidget {
  const MeasurementPickerColumn({
    super.key,
    required this.label,
    required this.unit,
    required this.wheel,
    required this.enabled,
    required this.onToggle,
    required this.toggleColor,
    this.footer,
    this.scale = 1.0,
  });

  final String label;
  final String unit;
  final Widget wheel;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  /// トグルON時のトラック色（子のテーマ色）。
  final Color toggleColor;

  /// ピッカー下部に出す補足（体重の g 換算表示など）。
  final Widget? footer;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13 * s,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 13 * s,
                color: enabled
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.4),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.78 * s,
              child: Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: toggleColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: enabled ? 1.0 : 0.35,
          child: AbsorbPointer(
            absorbing: !enabled,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * s),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16 * s),
              ),
              child: wheel,
            ),
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 6),
          Opacity(opacity: enabled ? 1.0 : 0.35, child: footer),
        ],
      ],
    );
  }
}
