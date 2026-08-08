import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../graph/graph_layout_constants.dart';
import '../growth/growth_lms_2000.dart';
import '../growth/sd_curves.dart';

/// 成長曲線・SDスコアの2つのグラフを、グラフ画面（タップ操作あり）と
/// 画像書き出し（静的）の両方で同じ見た目で描くための共有ウィジェット群。
///
/// もとは GrowthHomeScreen の State に埋め込まれていた描画コードを、
/// 「データ＋表示範囲＋スタイル」だけを受け取る StatelessWidget に分離した。
/// タップ検出などの画面専用の層は、呼び出し側（グラフ画面）が
/// [GrowthCurveChart.plotForeground] や [SdScoreChart.lineTouchData] で注入する。

/// 1記録ぶんのプロット点（age は基準日からの年齢・年単位）。
typedef GrowthRecordPoint = ({DateTime date, double age, double? h, double? w});

/// グラフの Y 軸スケール（描画範囲のみ。ラベル数値は固定定数で指定）。
typedef GrowthAxisScale = ({double plotMin, double plotMax});

/// 横スクロール年齢セレクターの選択肢（歳）。
const kGrowthAgeRangeOptions = [1, 2, 4, 8, 12, 18];

/// 系列色（身長=青／体重=オレンジ）。
const Color kGrowthHeightSeriesColor = Color(0xFF1565C0);
const Color kGrowthWeightSeriesColor = Color(0xFFE65100);

/// SD バンド（±2SD 等）の基準色。
const Color kSdBandColor = Color(0xFF66BB6A);

/// 年齢モード別・X 軸固定目盛り（左→右）。
const _kXAxisTickLabels = <int, List<int>>{
  1: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  2: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24],
  4: [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48],
  8: [0, 1, 2, 3, 4, 5, 6, 7, 8],
  12: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  18: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18],
};

/// 年齢モード別・X 軸単位（数字行の下に独立配置）。
const _kXAxisUnitSuffix = <int, String>{
  1: '月齢（か月）',
  2: '月齢（か月）',
  4: '月齢（か月）',
  8: '年齢（歳）',
  12: '年齢（歳）',
  18: '年齢（歳）',
};

/// 年齢モード別・X 軸縦グリッド間隔（chart 座標 = 年）。
const _kXAxisVerticalInterval = <int, double>{
  1: 1 / 12,
  2: 2 / 12,
  4: 4 / 12,
  8: 1.0,
  12: 1.0,
  18: 2.0,
};

/// 子の現在年齢から適切な表示範囲（X軸上限・歳）を選ぶ
/// （例：0歳6か月 → ～1歳）。
int autoGrowthAgeRangeYears(DateTime baseDate, {DateTime? asOf}) {
  final years = (asOf ?? DateTime.now()).difference(baseDate).inDays / 365.25;
  for (final opt in kGrowthAgeRangeOptions) {
    if (years < opt) return opt;
  }
  return kGrowthAgeRangeOptions.last;
}

List<int> growthXAxisTickLabelsForMode(int ageYears) =>
    _kXAxisTickLabels[ageYears] ?? _kXAxisTickLabels[4]!;

String growthXAxisUnitSuffixForMode(int ageYears) =>
    _kXAxisUnitSuffix[ageYears] ?? _kXAxisUnitSuffix[4]!;

double growthXAxisVerticalIntervalForMode(int ageYears) =>
    _kXAxisVerticalInterval[ageYears] ?? _kXAxisVerticalInterval[4]!;

/// 年齢チップごとの固定 Y 軸描画範囲（身長・体重）。
({GrowthAxisScale height, GrowthAxisScale weight}) growthFixedAxisPair(
  int ageYears,
) {
  switch (ageYears) {
    case 1:
      // 身長帯（下端）と体重帯（上端）が重ならないよう、身長は下へ
      // 体重は上へレンジを広げ、身長を上段・体重を下段に分離する。
      // 身長は上端に1目盛りの空きを確保（グラフ上部の切り替えボタン
      // と +2SD 曲線が重ならないように全体を1目盛り下げている）。
      return (
        height: (plotMin: 5, plotMax: 90),
        weight: (plotMin: 0, plotMax: 17),
      );
    case 2:
      return (
        height: (plotMin: 30, plotMax: 105),
        weight: (plotMin: 0, plotMax: 30),
      );
    case 4:
      return (
        height: (plotMin: 30, plotMax: 115),
        weight: (plotMin: 0, plotMax: 34),
      );
    case 8:
      return (
        height: (plotMin: 0, plotMax: 150),
        weight: (plotMin: 0, plotMax: 75),
      );
    case 12:
      // 12歳付近で身長 -2SD と体重 +2SD が接近するため、1歳と同様に
      // レンジを広げて身長を上段・体重を下段に分離する。
      return (
        height: (plotMin: -20, plotMax: 180),
        weight: (plotMin: 0, plotMax: 100),
      );
    case 18:
      return (
        height: (plotMin: 30, plotMax: 210),
        weight: (plotMin: 0, plotMax: 180),
      );
    default:
      return growthFixedAxisPair(4);
  }
}

/// 年齢モードごとの横グリッド線本数（= Y 軸固定ラベル配列長）。
int growthYAxisDivisionCount(int ageYears) =>
    GraphLayoutConstants.yGridLineCountForMode(ageYears);

double growthYGridInterval(GrowthAxisScale scale, int divisions) {
  if (divisions <= 1) return scale.plotMax - scale.plotMin;
  return (scale.plotMax - scale.plotMin) / (divisions - 1);
}

/// 系列色を軸ラベル向けにわずかに落ち着かせ、白背景でも読みやすくする。
Color growthSeriesAxisLabelColor(Color seriesColor) =>
    Color.lerp(seriesColor, const Color(0xFF263238), 0.18)!;

/// 成長曲線 chart：左右 Y 軸の reservedSize のみ確保（上層オーバーレイ用）。
FlTitlesData growthYAxisPlaceholderTitles({
  required double horizontalInterval,
  required double reservedSize,
}) {
  final side = SideTitles(
    showTitles: true,
    reservedSize: reservedSize,
    interval: horizontalInterval,
    getTitlesWidget: (_, _) => const SizedBox.shrink(),
  );
  return FlTitlesData(
    leftTitles: AxisTitles(sideTitles: side),
    rightTitles: AxisTitles(sideTitles: side),
    topTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    ),
    bottomTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    ),
  );
}

/// 画面幅に応じた UI 拡大率（グラフ画面）や書き出し倍率（=1.0 固定）を
/// フォント・確保領域へ同率で適用するためのスタイル。
class GrowthChartStyle {
  const GrowthChartStyle({this.uiScale = 1.0});

  final double uiScale;

  double get yAxisReservedSize => 34 * uiScale;

  /// X 軸：数字行 + 単位行。
  double get xAxisNumbersHeight => 22 * uiScale;
  double get xAxisUnitHeight => 16 * uiScale;
  double get bottomAxisReservedSize => xAxisNumbersHeight + xAxisUnitHeight;

  /// 軸数値ラベル（横・縦共通）。
  double get axisNumberFontSize => 12 * uiScale;
}

const FontWeight _kAxisNumberFontWeight = FontWeight.w500;

TextStyle _yAxisNumberStyle(GrowthChartStyle style, Color seriesColor) =>
    TextStyle(
      fontSize: style.axisNumberFontSize,
      fontWeight: _kAxisNumberFontWeight,
      height: 1.0,
      color: growthSeriesAxisLabelColor(seriesColor),
    );

TextStyle _xAxisNumberStyle(GrowthChartStyle style, ColorScheme scheme) =>
    TextStyle(
      fontSize: style.axisNumberFontSize,
      fontWeight: _kAxisNumberFontWeight,
      height: 1.0,
      color: scheme.onSurfaceVariant,
    );

/// X 軸単位ラベル（「月齢（か月）」「年齢（歳）」）。
TextStyle _xAxisUnitSuffixStyle(GrowthChartStyle style, ColorScheme scheme) =>
    _xAxisNumberStyle(
      style,
      scheme,
    ).copyWith(fontSize: 10 * style.uiScale, fontWeight: FontWeight.w600);

/// Y 軸単位ラベル（(kg)/(cm)）：X 軸単位ラベルと同じサイズ・太さ、系列色のみ差別化。
TextStyle _yAxisUnitTitleStyle(
  GrowthChartStyle style,
  Color seriesColor,
  ColorScheme scheme,
) => _xAxisUnitSuffixStyle(style, scheme).copyWith(color: seriesColor);

double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

Offset _plotSpotToOffset(
  FlSpot spot,
  Size plotSize, {
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
}) {
  final xRange = maxX - minX;
  final yRange = maxY - minY;
  if (xRange <= 0 || yRange <= 0) return Offset.zero;
  return Offset(
    (spot.x - minX) / xRange * plotSize.width,
    plotSize.height - (spot.y - minY) / yRange * plotSize.height,
  );
}

/// 下 X 軸数字行：各目盛りの中心を縦グリッド位置 i/(n-1) に固定。
Widget _buildStaticXAxisNumbersRow({
  required GrowthChartStyle style,
  required List<int> tickLabels,
  required ColorScheme scheme,
}) {
  final textStyle = _xAxisNumberStyle(style, scheme);
  final tickCount = tickLabels.length;
  if (tickCount == 0) return const SizedBox.shrink();

  return LayoutBuilder(
    builder: (context, constraints) {
      final plotWidth = constraints.maxWidth;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < tickCount; i++)
            Builder(
              builder: (context) {
                final text = '${tickLabels[i]}';
                final halfW = _measureTextWidth(context, text, textStyle) / 2;
                final centerX = tickCount <= 1
                    ? plotWidth
                    : plotWidth * i / (tickCount - 1);
                final slotAlign = i == 0
                    ? Alignment.centerLeft
                    : i == tickCount - 1
                    ? Alignment.centerRight
                    : Alignment.center;

                return Positioned(
                  left: centerX - halfW,
                  width: halfW * 2,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: slotAlign,
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: textStyle,
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

/// 下 X 軸：数字行 + 単位行（fl_chart titlesData 不使用）。
Widget _buildStaticXAxisLabels({
  required GrowthChartStyle style,
  required List<int> tickLabels,
  required String unitSuffix,
  required ColorScheme scheme,
}) {
  if (tickLabels.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: style.xAxisNumbersHeight,
        child: _buildStaticXAxisNumbersRow(
          style: style,
          tickLabels: tickLabels,
          scheme: scheme,
        ),
      ),
      SizedBox(
        height: style.xAxisUnitHeight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            unitSuffix,
            maxLines: 1,
            softWrap: false,
            style: _xAxisUnitSuffixStyle(style, scheme),
          ),
        ),
      ),
    ],
  );
}

/// 成長曲線 chart のグリッド（Y 固定分割 + X 目盛り数に同期した縦線）。
FlGridData _buildGrowthGridData({
  required GrowthAxisScale scale,
  required int yDivisions,
  required double minX,
  required double verticalInterval,
  required int verticalLineCount,
}) {
  final horizontalInterval = growthYGridInterval(scale, yDivisions);
  return FlGridData(
    show: true,
    drawVerticalLine: true,
    drawHorizontalLine: true,
    verticalInterval: verticalInterval,
    horizontalInterval: horizontalInterval,
    checkToShowVerticalLine: (x) {
      final rel = (x - minX) / verticalInterval;
      final k = rel.round();
      return (rel - k).abs() < 0.08 && k >= 0 && k <= verticalLineCount - 1;
    },
    checkToShowHorizontalLine: (y) {
      final rel = (y - scale.plotMin) / horizontalInterval;
      final k = rel.round();
      return (rel - k).abs() < 0.08 && k >= 0 && k <= yDivisions - 1;
    },
    getDrawingVerticalLine: (x) => FlLine(
      color: Colors.grey.withValues(alpha: 0.2),
      strokeWidth: 0.8,
      dashArray: const [4, 4],
    ),
    getDrawingHorizontalLine: (y) => FlLine(
      color: Colors.grey.withValues(alpha: 0.2),
      strokeWidth: 0.8,
      dashArray: const [4, 4],
    ),
  );
}

/// SD 基準カーブから「基準線（薄い系列色）＋バンド塗り＋実データ線」を構築。
///
/// 描画順序が重要：fl_chart は betweenBarsData→lineBars(index順) の順に描く。
/// 実データ線を末尾 index に置くことで、塗り・基準線の上に確実に重なる。
({List<LineChartBarData> bars, List<BetweenBarsData> bands}) _sdBarsAndBands({
  required List<SdCurve> curves,
  required Color seriesColor,
  required List<FlSpot> userSpots,
}) {
  final bars = <LineChartBarData>[
    for (final c in curves)
      _refLine(
        c.spots,
        seriesColor.withValues(alpha: c.showLabel ? 0.30 : 0.15),
      ),
    if (userSpots.isNotEmpty) growthUserLine(userSpots, seriesColor),
  ];

  int idxOf(double sd) => curves.indexWhere((c) => (c.sd - sd).abs() < 1e-6);
  final i2 = idxOf(2);
  final iM2 = idxOf(-2);
  final i1 = idxOf(1);
  final iM1 = idxOf(-1);

  final bands = <BetweenBarsData>[
    if (i2 >= 0 && iM2 >= 0)
      BetweenBarsData(
        fromIndex: i2,
        toIndex: iM2,
        color: seriesColor.withValues(alpha: 0.05),
      ),
    if (i1 >= 0 && iM1 >= 0)
      BetweenBarsData(
        fromIndex: i1,
        toIndex: iM1,
        color: seriesColor.withValues(alpha: 0.08),
      ),
  ];

  return (bars: bars, bands: bands);
}

/// 基準線は 1ヶ月刻み＋単調3次補間で点が十分滑らかなため折れ線で描く。
/// ベジェ補間（isCurved: true）は制御点のはみ出しで帯が波打つため使わない。
LineChartBarData _refLine(List<FlSpot> spots, Color color) => LineChartBarData(
  spots: spots,
  color: color,
  barWidth: 0.8,
  isCurved: false,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(show: false),
);

/// 実測値の折れ線（丸ドット付き）。
LineChartBarData growthUserLine(
  List<FlSpot> spots,
  Color color, {
  bool curved = true,
}) => LineChartBarData(
  spots: spots,
  color: color,
  barWidth: 2.5,
  isCurved: curved,
  dotData: FlDotData(
    show: true,
    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
      radius: 3.5,
      color: color,
      strokeWidth: 1.5,
      strokeColor: Colors.white,
    ),
  ),
  belowBarData: BarAreaData(show: false),
);

/// SD 基準線の名札。帯の塗り・曲線に重なっても読めるよう半透明白の
/// 下敷き＋太字で浮かせる（完全な白にせず、下の測定線がうっすら透ける）。
/// 文字色は系列色（身長=青／体重=オレンジ）でどちらの基準か判別できる。
/// 右端に縦に並ぶため、隣のラベルと干渉しないようコンパクトに保つ。
Widget _sdInlineLabel(GrowthChartStyle style, String text, Color seriesColor) =>
    Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: seriesColor.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7.5 * style.uiScale,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: seriesColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );

/// 母子手帳スタイルの成長曲線（身長・体重の重ね合わせ＋SD基準帯）。
///
/// 軸ラベルは LineChart 外側の Column/Row で描画し、プロット領域には
/// 水平グリッドと曲線のみを fl_chart に任せる。
class GrowthCurveChart extends StatelessWidget {
  const GrowthCurveChart({
    super.key,
    required this.isBoy,
    required this.recordPoints,
    required this.ageRangeYears,
    this.style = const GrowthChartStyle(),
    this.plotForeground,
    this.raiseUnitLabels = false,
  });

  final bool isBoy;

  /// 年齢昇順のプロット点。
  final List<GrowthRecordPoint> recordPoints;

  /// X 軸の表示上限（歳）。[kGrowthAgeRangeOptions] のいずれか。
  final int ageRangeYears;

  final GrowthChartStyle style;

  /// プロット領域の最前面に重ねる画面専用レイヤー
  /// （グラフ画面のタップ検出チャートなど）。書き出しでは null。
  final Widget? plotForeground;

  /// true なら (kg)/(cm) の単位ラベルを目盛り線の中心に1行で置く
  /// （書き出し画像用。半行ぶん上がり、すぐ下の目盛り数字と重ならない）。
  /// false（既定）はアプリ画面の従来表示（改行付きで下寄り）。
  final bool raiseUnitLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const minX = 0.0;
    final maxX = ageRangeYears.toDouble();
    final xGridInterval = growthXAxisVerticalIntervalForMode(ageRangeYears);
    final xTickLabels = growthXAxisTickLabelsForMode(ageRangeYears);
    final xUnitSuffix = growthXAxisUnitSuffixForMode(ageRangeYears);
    final yDivisions = growthYAxisDivisionCount(ageRangeYears);
    final weightLabels = GraphLayoutConstants.weightLabelsForMode(
      ageRangeYears,
    );
    final heightLabels = GraphLayoutConstants.heightLabelsForMode(
      ageRangeYears,
    );
    assert(
      weightLabels.length == yDivisions && heightLabels.length == yDivisions,
      'Y axis label count must match grid division count',
    );
    final fixedAxes = growthFixedAxisPair(ageRangeYears);
    final heightScale = fixedAxes.height;
    final weightScale = fixedAxes.weight;
    final horizontalInterval = growthYGridInterval(heightScale, yDivisions);

    final heightSdCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: true);
    final weightSdCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: false);

    final heightChart = _buildHeightChart(
      scheme: scheme,
      minX: minX,
      maxX: maxX,
      yDivisions: yDivisions,
      xGridInterval: xGridInterval,
      xGridLineCount: xTickLabels.length,
      heightScale: heightScale,
      weightLabels: weightLabels,
      heightLabels: heightLabels,
      horizontalInterval: horizontalInterval,
      sdCurves: heightSdCurves,
    );
    final weightChart = _buildWeightChart(
      minX: minX,
      maxX: maxX,
      weightScale: weightScale,
      horizontalInterval: horizontalInterval,
      sdCurves: weightSdCurves,
    );

    final plotBorder = Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      width: 0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final yAxisReserved = style.yAxisReservedSize;
                    final plotWidth = constraints.maxWidth - yAxisReserved * 2;
                    final plotSize = Size(plotWidth, constraints.maxHeight);

                    Widget sdLabel(
                      SdCurve curve,
                      GrowthAxisScale scale,
                      Color seriesColor,
                    ) {
                      // どの線の名札か迷わないよう、ラベルは線上（右端）に直接
                      // 載せる（半透明の下敷きごしに線が通り抜けて見える）。
                      final endpoint = curve.spots.lastWhere(
                        (s) => s.x <= maxX + 1e-6,
                        orElse: () => curve.spots.last,
                      );
                      final pos = _plotSpotToOffset(
                        endpoint,
                        plotSize,
                        minX: minX,
                        maxX: maxX,
                        minY: scale.plotMin,
                        maxY: scale.plotMax,
                      );
                      final labelMaxWidth = 52.0 * style.uiScale;
                      final left =
                          yAxisReserved +
                          (pos.dx - labelMaxWidth + 2).clamp(
                            2.0,
                            plotSize.width - labelMaxWidth - 2,
                          );
                      return Positioned(
                        left: left,
                        top: pos.dy - 7,
                        width: labelMaxWidth,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _sdInlineLabel(style, curve.label, seriesColor),
                        ),
                      );
                    }

                    // 凡例行の代わりに、系列名をグラフ中央付近へ薄い色文字で
                    // 直接書く。身長は +2.0SD 曲線の少し上、体重は -2.0SD 曲線の
                    // 少し下に置くと帯と重ならず、どの帯がどの系列かも一目でわかる。
                    Widget seriesNameLabel({
                      required List<SdCurve> curves,
                      required GrowthAxisScale scale,
                      required double anchorSd,
                      required bool above,
                      required String text,
                      required Color seriesColor,
                    }) {
                      final curve = curves.firstWhere((c) => c.sd == anchorSd);
                      final midX = (minX + maxX) / 2;
                      final anchor = curve.spots.reduce(
                        (a, b) =>
                            (a.x - midX).abs() <= (b.x - midX).abs() ? a : b,
                      );
                      final pos = _plotSpotToOffset(
                        FlSpot(midX, anchor.y),
                        plotSize,
                        minX: minX,
                        maxX: maxX,
                        minY: scale.plotMin,
                        maxY: scale.plotMax,
                      );
                      final fontSize = 14.0 * style.uiScale;
                      const labelWidth = 80.0;
                      return Positioned(
                        left: yAxisReserved + pos.dx - labelWidth / 2,
                        top: above ? pos.dy - fontSize - 8 : pos.dy + 6,
                        width: labelWidth,
                        child: IgnorePointer(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: 2,
                              color: seriesColor.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      );
                    }

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: yAxisReserved,
                          right: yAxisReserved,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(border: plotBorder),
                          ),
                        ),
                        Positioned.fill(child: heightChart),
                        Positioned.fill(child: weightChart),
                        if (heightSdCurves.isNotEmpty)
                          seriesNameLabel(
                            curves: heightSdCurves,
                            scale: heightScale,
                            anchorSd: 2.0,
                            above: true,
                            text: '身長',
                            seriesColor: kGrowthHeightSeriesColor,
                          ),
                        if (weightSdCurves.isNotEmpty)
                          seriesNameLabel(
                            curves: weightSdCurves,
                            scale: weightScale,
                            anchorSd: -2.0,
                            above: false,
                            text: '体重',
                            seriesColor: kGrowthWeightSeriesColor,
                          ),
                        for (final curve in heightSdCurves)
                          if (curve.showLabel && curve.spots.isNotEmpty)
                            sdLabel(curve, heightScale, kGrowthHeightSeriesColor),
                        for (final curve in weightSdCurves)
                          if (curve.showLabel && curve.spots.isNotEmpty)
                            sdLabel(curve, weightScale, kGrowthWeightSeriesColor),
                        if (plotForeground != null)
                          Positioned.fill(child: plotForeground!),
                      ],
                    );
                  },
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: style.yAxisReservedSize),
                  Expanded(
                    child: _buildStaticXAxisLabels(
                      style: style,
                      tickLabels: xTickLabels,
                      unitSuffix: xUnitSuffix,
                      scheme: scheme,
                    ),
                  ),
                  SizedBox(width: style.yAxisReservedSize),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// GraphLayoutConstants 配列を fl_chart グリッド線位置に同期して描画。
  FlTitlesData _buildYAxisTitlesData({
    required ColorScheme scheme,
    required List<String> weightLabels,
    required List<String> heightLabels,
    required double horizontalInterval,
  }) {
    SideTitles sideTitles({
      required List<String> labelList,
      required Color seriesColor,
      required TextAlign textAlign,
      required String unitLabelText,
    }) {
      final topIndex = labelList.indexWhere((e) => e.isNotEmpty);
      final unitStyle = _yAxisUnitTitleStyle(style, seriesColor, scheme);

      return SideTitles(
        showTitles: true,
        reservedSize: style.yAxisReservedSize,
        interval: horizontalInterval,
        getTitlesWidget: (value, meta) {
          final interval = meta.appliedInterval;
          if (interval <= 0) return const SizedBox.shrink();
          final index = ((meta.max - value) / interval).round();
          if (index < 0 || index >= labelList.length) {
            return const SizedBox.shrink();
          }
          if (topIndex >= 0 && index == topIndex - 1) {
            return Text(unitLabelText, textAlign: textAlign, style: unitStyle);
          }
          final text = labelList[index];
          if (text.isEmpty) {
            return const SizedBox.shrink();
          }
          return Text(
            text,
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: _yAxisNumberStyle(style, seriesColor),
          );
        },
      );
    }

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: sideTitles(
          labelList: weightLabels,
          seriesColor: kGrowthWeightSeriesColor,
          textAlign: TextAlign.right,
          // 先頭の改行ありだと2行ぶんの高さで下寄りに描かれる（画面の従来表示）。
          // 書き出しでは改行なしで目盛り位置の中心に置き、目盛り数字との
          // 重なりを避ける。
          unitLabelText: raiseUnitLabels ? '(kg)' : '\n(kg)',
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: sideTitles(
          labelList: heightLabels,
          seriesColor: kGrowthHeightSeriesColor,
          textAlign: TextAlign.left,
          unitLabelText: raiseUnitLabels ? '(cm)' : '\n(cm)',
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false, reservedSize: 0),
      ),
      bottomTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false, reservedSize: 0),
      ),
    );
  }

  /// 下層：身長・基準線・グリッド（横線+縦線）・左右 Y 軸ラベル。
  Widget _buildHeightChart({
    required ColorScheme scheme,
    required double minX,
    required double maxX,
    required int yDivisions,
    required double xGridInterval,
    required int xGridLineCount,
    required GrowthAxisScale heightScale,
    required List<String> weightLabels,
    required List<String> heightLabels,
    required double horizontalInterval,
    required List<SdCurve> sdCurves,
  }) {
    // 0以下は不正値扱い（タップ対象・SD計算と同じ基準でそろえる）。
    final userHSpots = recordPoints
        .where(
          (r) =>
              r.h != null &&
              r.h! > 0 &&
              r.age >= minX - 0.01 &&
              r.age <= maxX + 0.01,
        )
        .map((r) => FlSpot(r.age, r.h!))
        .toList();

    final sd = _sdBarsAndBands(
      curves: sdCurves,
      seriesColor: kGrowthHeightSeriesColor,
      userSpots: userHSpots,
    );

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: heightScale.plotMin,
        maxY: heightScale.plotMax,
        baselineX: minX,
        baselineY: heightScale.plotMin,
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        betweenBarsData: sd.bands,
        gridData: _buildGrowthGridData(
          scale: heightScale,
          yDivisions: yDivisions,
          minX: minX,
          verticalInterval: xGridInterval,
          verticalLineCount: xGridLineCount,
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildYAxisTitlesData(
          scheme: scheme,
          weightLabels: weightLabels,
          heightLabels: heightLabels,
          horizontalInterval: horizontalInterval,
        ),
        lineBarsData: sd.bars,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// 上層（透明）：体重・体重基準線のみ。Y 軸は reservedSize のみ確保。
  Widget _buildWeightChart({
    required double minX,
    required double maxX,
    required GrowthAxisScale weightScale,
    required double horizontalInterval,
    required List<SdCurve> sdCurves,
  }) {
    // 0以下は不正値扱い（タップ対象・SD計算と同じ基準でそろえる）。
    final userWSpots = recordPoints
        .where(
          (r) =>
              r.w != null &&
              r.w! > 0 &&
              r.age >= minX - 0.01 &&
              r.age <= maxX + 0.01,
        )
        .map((r) => FlSpot(r.age, r.w!))
        .toList();

    final sd = _sdBarsAndBands(
      curves: sdCurves,
      seriesColor: kGrowthWeightSeriesColor,
      userSpots: userWSpots,
    );

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: weightScale.plotMin,
        maxY: weightScale.plotMax,
        baselineX: minX,
        baselineY: weightScale.plotMin,
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        betweenBarsData: sd.bands,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: growthYAxisPlaceholderTitles(
          horizontalInterval: horizontalInterval,
          reservedSize: style.yAxisReservedSize,
        ),
        lineBarsData: sd.bars,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }
}

/// SDスコア専用グラフ。軸ラベルは LineChart 外側で描画。
class SdScoreChart extends StatelessWidget {
  const SdScoreChart({
    super.key,
    required this.isBoy,
    required this.recordPoints,
    required this.ageRangeYears,
    this.style = const GrowthChartStyle(),
    this.lineTouchData,
    this.verticalLines = const <VerticalLine>[],
    this.chartKey,
  });

  final bool isBoy;
  final List<GrowthRecordPoint> recordPoints;
  final int ageRangeYears;

  final GrowthChartStyle style;

  /// 画面専用のタップ検出設定。書き出しでは null（タップ無効）。
  final LineTouchData? lineTouchData;

  /// 選択中レコードの指示線など、画面専用の縦線。
  final List<VerticalLine> verticalLines;

  /// タップ位置の座標変換用に chart に持たせるキー（画面専用）。
  final Key? chartKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const minX = 0.0;
    final maxX = ageRangeYears.toDouble();
    final xGridInterval = growthXAxisVerticalIntervalForMode(ageRangeYears);
    final xTickLabels = growthXAxisTickLabelsForMode(ageRangeYears);
    final xUnitSuffix = growthXAxisUnitSuffixForMode(ageRangeYears);

    final hData = GrowthLms2000.heightRef(isBoy: isBoy);
    final wData = GrowthLms2000.weightRef(isBoy: isBoy);
    final hSpots = <FlSpot>[];
    final wSpots = <FlSpot>[];
    var maxAbs = 2.0;
    for (final r in recordPoints) {
      if (r.age < minX - 0.01 || r.age > maxX + 0.01) continue;
      final months = r.age * 12;
      final h = r.h;
      final w = r.w;
      // 0以下は不正値扱いで点を打たない（zScore が 0 を返し平均線上に
      // 偽の点が出てしまうため）。
      if (h != null && h > 0) {
        final hz = hData.zScore(months, h);
        hSpots.add(FlSpot(r.age, hz));
        if (hz.abs() > maxAbs) maxAbs = hz.abs();
      }
      if (w != null && w > 0) {
        final wz = wData.zScore(months, w);
        wSpots.add(FlSpot(r.age, wz));
        if (wz.abs() > maxAbs) maxAbs = wz.abs();
      }
    }
    // 基本は ±3.0 固定。実測が外れる場合のみ ±4.0 へ拡張して見切れ防止。
    final yLimit = maxAbs <= 3.0 ? 3.0 : 4.0;

    // ライン上の文字ラベルは付けない（左右の外付け軸ラベルで値を示す）。
    HorizontalLine sdLine(
      double y, {
      required bool dashed,
      required Color color,
      double width = 1,
    }) => HorizontalLine(
      y: y,
      color: color,
      strokeWidth: width,
      dashArray: dashed ? const [6, 4] : null,
    );

    final plotBorder = Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      width: 0.5,
    );

    Widget chart = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: -yLimit,
        maxY: yLimit,
        clipData: const FlClipData.all(),
        lineTouchData: lineTouchData ?? const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          verticalInterval: xGridInterval,
          // 0.5 刻みで補助線を引く（±0.5・±1.5 なども読み取れるように）。
          horizontalInterval: 0.5,
          checkToShowVerticalLine: (x) {
            final rel = (x - minX) / xGridInterval;
            final k = rel.round();
            return (rel - k).abs() < 0.08 &&
                k >= 0 &&
                k <= xTickLabels.length - 1;
          },
          checkToShowHorizontalLine: (v) {
            final half = v * 2;
            final isHalfStep = (half - half.roundToDouble()).abs() < 1e-6;
            final r2 = half.round();
            // 0 と ±2 は extraLines の専用線（平均・緑破線）に任せる。
            return isHalfStep && r2 != 0 && r2 != 4 && r2 != -4;
          },
          getDrawingVerticalLine: (x) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            strokeWidth: 0.5,
          ),
          // 整数線をやや濃く、0.5 刻みの補助線を淡くして読み分けやすくする。
          getDrawingHorizontalLine: (y) {
            final isInt = (y - y.roundToDouble()).abs() < 1e-6;
            return FlLine(
              color: scheme.outlineVariant.withValues(
                alpha: isInt ? 0.40 : 0.15,
              ),
              strokeWidth: 0.5,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false, reservedSize: 0),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false, reservedSize: 0),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false, reservedSize: 0),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false, reservedSize: 0),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            sdLine(2, dashed: true, color: kSdBandColor),
            sdLine(-2, dashed: true, color: kSdBandColor),
            sdLine(
              0,
              dashed: false,
              color: scheme.onSurface.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ],
          // 選択中レコードの位置を示す縦線（詳細ボックスとセットで表示）。
          verticalLines: verticalLines,
        ),
        // 注意：lineBarsData を空リストにすると fl_chart が基準線
        // （extraLinesData の ±2SD・平均線）ごと描画をスキップするため、
        // 表示範囲内に記録が無くても空スポットの系列を常に渡す。
        lineBarsData: [
          growthUserLine(hSpots, kGrowthHeightSeriesColor),
          growthUserLine(wSpots, kGrowthWeightSeriesColor),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );

    if (chartKey != null) {
      chart = KeyedSubtree(key: chartKey, child: chart);
    }

    // 軸ラベル列はプロット領域と同じ高さに揃える必要があるため、
    // X 軸ラベル行（数字＋単位）ぶんの下余白を差し引く。
    final xAxisLabelsHeight =
        style.xAxisNumbersHeight + style.xAxisUnitHeight;
    Widget yAxisColumn(Alignment alignment) => SizedBox(
      width: style.yAxisReservedSize,
      child: Padding(
        padding: EdgeInsets.only(bottom: xAxisLabelsHeight),
        child: _buildExternalYAxisColumn(
          yLimit: yLimit,
          scheme: scheme,
          alignment: alignment,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // 上端のラベル（+3.0 等）は線に上下中央で揃えるため半分だけ
          // プロットの上へはみ出す。ページ切り替え等でクリップされて
          // 欠けないよう、プロット全体の上に半ラベルぶんの余白を確保する。
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                yAxisColumn(Alignment.centerRight),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(border: plotBorder),
                              ),
                            ),
                            Positioned.fill(child: chart),
                          ],
                        ),
                      ),
                      _buildStaticXAxisLabels(
                        style: style,
                        tickLabels: xTickLabels,
                        unitSuffix: xUnitSuffix,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
                // 右側にも左と同じ軸ラベルを外付けで表示する。
                yAxisColumn(Alignment.centerLeft),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sdYAxisLabelText(int v, ColorScheme scheme) {
    // 「+2.0」「-1.0」「0」表記（グラフ内の SD 値と桁を揃える）。
    final txt = v == 0 ? '0' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    final Color c;
    if (v == 0) {
      c = scheme.onSurface.withValues(alpha: 0.75);
    } else if (v == 2 || v == -2) {
      c = kSdBandColor;
    } else {
      c = scheme.onSurfaceVariant;
    }
    return Text(
      txt,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: c,
        height: 1.0,
      ),
    );
  }

  /// SD スコアグラフの外付け Y 軸ラベル列（左右共通）。
  /// 各ラベルはグリッド線の Y 位置に「上下中央」で揃うよう実座標で配置する
  /// （以前の Expanded 均等割りは行の上端揃えになり線とズレていた）。
  Widget _buildExternalYAxisColumn({
    required double yLimit,
    required ColorScheme scheme,
    required Alignment alignment,
  }) {
    final limit = yLimit.round();
    const labelHeight = 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var v = limit; v >= -limit; v--)
              Positioned(
                top: (limit - v) / (2 * limit) * h - labelHeight / 2,
                left: 0,
                right: 0,
                height: labelHeight,
                child: Align(
                  alignment: alignment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _sdYAxisLabelText(v, scheme),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// SD スコアグラフ用の凡例（身長・体重・正常範囲）。
class SdChartLegend extends StatelessWidget {
  const SdChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendEntry(kGrowthHeightSeriesColor, '身長'),
            const SizedBox(width: 12),
            _legendEntry(kGrowthWeightSeriesColor, '体重'),
            const SizedBox(width: 12),
            _legendEntry(kSdBandColor, '正常範囲(±2SD)'),
          ],
        ),
      ),
    );
  }

  Widget _legendEntry(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: growthSeriesAxisLabelColor(color),
        ),
      ),
    ],
  );
}
