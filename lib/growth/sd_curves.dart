import 'package:fl_chart/fl_chart.dart';

import 'growth_lms_2000.dart';
import 'lms_reference.dart';

/// 成長曲線グラフに描く 1 本の SD 基準カーブ。
class SdCurve {
  const SdCurve({
    required this.label,
    required this.sd,
    required this.spots,
    required this.showLabel,
  });

  final String label;
  final double sd;

  /// X = 年齢（年）、Y = 身長(cm) or 体重(kg)。
  final List<FlSpot> spots;

  final bool showLabel;
}

/// ±2/±1/平均 の SD 基準カーブ群（LMS 法・Isojima 2016 準拠）。
///
/// 基準データは実行中に変化しないため、性別×項目の全4パターンを
/// 初回生成後にキャッシュし、build ごとの再計算を避ける。
class SdCurves {
  SdCurves._();

  static final _cache = <(bool isBoy, bool isHeight), List<SdCurve>>{};

  static List<SdCurve> forSeries({
    required bool isBoy,
    required bool isHeight,
  }) =>
      _cache.putIfAbsent(
        (isBoy, isHeight),
        () => _build(isBoy: isBoy, isHeight: isHeight),
      );

  static List<SdCurve> _build({
    required bool isBoy,
    required bool isHeight,
  }) {
    final ref = isHeight
        ? GrowthLms2000.heightRef(isBoy: isBoy)
        : GrowthLms2000.weightRef(isBoy: isBoy);
    const specs = <({String label, double sd, bool showLabel})>[
      (label: '+2.0SD', sd: 2.0, showLabel: true),
      (label: '+1.0SD', sd: 1.0, showLabel: true),
      (label: '平均', sd: 0.0, showLabel: true),
      (label: '-1.0SD', sd: -1.0, showLabel: true),
      (label: '-2.0SD', sd: -2.0, showLabel: true),
    ];
    return [
      for (final s in specs)
        SdCurve(
          label: s.label,
          sd: s.sd,
          showLabel: s.showLabel,
          spots: _spots(ref, s.sd),
        ),
    ];
  }

  /// LMS 基準から ±SD 曲線用 FlSpot 列を生成（X 軸 = 年）。
  /// 補間（単調3次）が滑らかさを担うため、1ヶ月刻みで十分密にサンプリングする。
  static List<FlSpot> _spots(LmsReference ref, double sdMultiplier) {
    const stepYears = 1 / 12;
    final maxYears = GrowthLms2000.maxAgeYears;
    final spots = <FlSpot>[];
    for (var ageYears = 0.0;
        ageYears <= maxYears + stepYears / 2;
        ageYears += stepYears) {
      spots.add(FlSpot(ageYears, ref.valueAtZ(ageYears * 12, sdMultiplier)));
    }
    return spots;
  }
}
