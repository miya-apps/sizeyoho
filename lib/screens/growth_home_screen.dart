import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';
import '../graph/graph_layout_constants.dart';
import '../growth/growth_lms_2000.dart';
import '../growth/sd_curves.dart';
import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';

/// グラフの Y 軸スケール（描画範囲のみ。ラベル数値は固定定数で指定）。
typedef _AxisScale = ({double plotMin, double plotMax});

/// 横スクロール年齢セレクターの選択肢（歳）。
const _kAgeRangeOptions = [1, 2, 4, 8, 12, 18];

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

class GrowthHomeScreen extends StatefulWidget {
  const GrowthHomeScreen({
    super.key,
    required this.child,
    this.chartTypeNotifier,
  });

  final ChildProfile child;

  /// 表示中のグラフ種類（0=成長曲線, 1=SDスコア）。
  /// AppShell のヘッダー右上トグルと双方向に同期するために使う。
  final ValueNotifier<int>? chartTypeNotifier;

  @override
  State<GrowthHomeScreen> createState() => _GrowthHomeScreenState();
}

class _GrowthHomeScreenState extends State<GrowthHomeScreen> {
  late List<GrowthRecord> _records;
  late PageController _chartPageController;

  /// PageView の現在ページ（0=成長曲線, 1=SDスコア）。
  int _chartPageIndex = 0;

  /// タップ中のデータ点詳細（自前オーバーレイ表示）。
  /// fl_chart 組み込みツールチップはキャンバス描画のため影が付けられず、
  /// フローティングボタンより奥に隠れるので、Widget として自前で重ねる。
  ({DateTime date, double age, double? h, double? w})? _detailRecord;

  /// 詳細ボックスのアンカー位置（チャートエリア Stack のローカル座標）。
  Offset? _detailPos;

  final GlobalKey _chartAreaStackKey = GlobalKey();
  final GlobalKey _growthTouchChartKey = GlobalKey();
  final GlobalKey _sdTouchChartKey = GlobalKey();

  void _clearDetailBox() {
    if (_detailRecord == null) return;
    setState(() {
      _detailRecord = null;
      _detailPos = null;
    });
  }

  /// 両グラフ共通のタップ処理。データ点近傍のタップで詳細ボックスを出し、
  /// 何もない場所のタップで消す。位置はチャート → エリア Stack へ座標変換。
  void _handleChartTouch(
    FlTouchEvent event,
    LineTouchResponse? response,
    GlobalKey chartKey,
    ({DateTime date, double age, double? h, double? w})? Function(
      LineBarSpot spot,
    )
    resolveRecord,
  ) {
    if (event is! FlTapUpEvent) return;
    final spots = response?.lineBarSpots;
    if (spots == null || spots.isEmpty) {
      _clearDetailBox();
      return;
    }
    final rec = resolveRecord(spots.first);
    if (rec == null) {
      _clearDetailBox();
      return;
    }
    final chartBox = chartKey.currentContext?.findRenderObject() as RenderBox?;
    final areaBox =
        _chartAreaStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (chartBox == null || areaBox == null) return;
    final pos = areaBox.globalToLocal(
      chartBox.localToGlobal(event.localPosition),
    );
    setState(() {
      _detailRecord = rec;
      _detailPos = pos;
    });
  }

  /// 横軸の表示上限（歳）。ChoiceChip で選択。
  int _selectedAgeRangeYears = 4;

  /// グラフを修正月齢（出産予定日基準）で表示中かどうか。
  /// この子が修正月齢非対応に切り替わっても [_ageBaseDate] 側で安全に
  /// 暦月齢へフォールバックするため、状態自体は保持しても害はない。
  bool _useCorrectedAgeView = false;

  /// 修正月齢表示のアクセント色。その子のテーマ色を黒に40%寄せた濃色で、
  /// くすみパステルでも白背景上で十分なコントラストを確保する
  /// （ボトムナビの選択色と同じ導出方法）。トグル・枠線・ラベルに使用。
  Color get _correctedAccent =>
      Color.lerp(_viewingChild.themeColor, Colors.black, 0.40)!;

  // ── Y 軸数値・単位は fl_chart titlesData（getTitlesWidget）で描画 ────────

  /// SD 基準線・帯は LMS 基準（0〜17.5歳）ぶん生成し、表示範囲外は fl_chart がクリップする。

  /// 画面幅に応じた UI 拡大率（軸ラベル・年齢セレクター等に適用、最大1.3倍）。
  /// フォントと確保領域（reservedSize 等）を同率で拡大するため、
  /// 大画面でもラベルとグリッドの位置整合が保たれる。
  double get _uiScale => uiScaleForWidth(MediaQuery.sizeOf(context).width);

  double get _growthChartYAxisReservedSize => 34 * _uiScale;

  /// X 軸：数字行 + 単位行。
  double get _growthChartXAxisNumbersHeight => 22 * _uiScale;
  double get _growthChartXAxisUnitHeight => 16 * _uiScale;
  double get _growthChartBottomAxisReservedSize =>
      _growthChartXAxisNumbersHeight + _growthChartXAxisUnitHeight;

  /// 成長曲線グラフの軸数値ラベル（横・縦共通）。
  double get _growthChartAxisNumberFontSize => 12 * _uiScale;
  static const FontWeight _growthChartAxisNumberFontWeight = FontWeight.w500;

  /// LineChart 内の軸ラベル・余白をすべて無効化（SD スコア chart 等）。
  static const FlTitlesData _hiddenChartTitles = FlTitlesData(
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
  );

  /// 成長曲線 chart：左右 Y 軸の reservedSize のみ確保（上層オーバーレイ用）。
  FlTitlesData _growthChartYAxisPlaceholderTitles({
    required double horizontalInterval,
  }) {
    final side = SideTitles(
      showTitles: true,
      reservedSize: _growthChartYAxisReservedSize,
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

  /// GraphLayoutConstants 配列を fl_chart グリッド線位置に同期して描画。
  FlTitlesData _buildGrowthChartYAxisTitlesData({
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
      final unitStyle = _growthYAxisUnitTitleStyle(seriesColor, scheme);

      return SideTitles(
        showTitles: true,
        reservedSize: _growthChartYAxisReservedSize,
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
            style: _yAxisNumberStyle(seriesColor),
          );
        },
      );
    }

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: sideTitles(
          labelList: weightLabels,
          seriesColor: _weightSeriesColor,
          textAlign: TextAlign.right,
          unitLabelText: '\n(kg)',
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: sideTitles(
          labelList: heightLabels,
          seriesColor: _heightSeriesColor,
          textAlign: TextAlign.left,
          unitLabelText: '\n(cm)',
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

  static const Color _heightSeriesColor = Color(0xFF1565C0);
  static const Color _weightSeriesColor = Color(0xFFE65100);

  /// 系列色を軸ラベル向けにわずかに落ち着かせ、白背景でも読みやすくする。
  static Color _seriesAxisLabelColor(Color seriesColor) =>
      Color.lerp(seriesColor, const Color(0xFF263238), 0.18)!;

  /// 現在タブで選択中の子供
  ChildProfile get _viewingChild => widget.child;

  /// 子の現在年齢から適切な表示範囲を選ぶ（例：0歳6か月 → ～1歳）。
  /// 手動で選び直せるのは従来どおりで、初期表示・子の切り替え時・
  /// 修正月齢への切り替え時に適用。修正月齢表示中は出産予定日基準の
  /// 年齢で選ぶ（境界付近で1段広い範囲が選ばれるのを防ぐ）。
  int _autoAgeRangeFor(ChildProfile child, {bool corrected = false}) {
    final base = corrected && child.expectedBirthDate != null
        ? child.expectedBirthDate!
        : child.birthDate;
    final years = DateTime.now().difference(base).inDays / 365.25;
    for (final opt in _kAgeRangeOptions) {
      if (years < opt) return opt;
    }
    return _kAgeRangeOptions.last;
  }

  @override
  void initState() {
    super.initState();
    // 子供切り替えで State が作り直されても、ヘッダーのトグル状態
    // （notifier の値）を初期ページとして引き継ぐ。
    _chartPageIndex = widget.chartTypeNotifier?.value ?? 0;
    _chartPageController = PageController(initialPage: _chartPageIndex);
    widget.chartTypeNotifier?.addListener(_onExternalChartType);
    _selectedAgeRangeYears = _autoAgeRangeFor(widget.child);
    _reloadForChild();
  }

  /// ヘッダー右上のトグル（AppShell 側）からの切り替えをページへ反映する。
  void _onExternalChartType() {
    final target = widget.chartTypeNotifier?.value;
    if (target == null || target == _chartPageIndex) return;
    // 凡例などページ番号に連動する UI はアニメーション完了を待たず即時更新。
    setState(() => _chartPageIndex = target);
    if (!_chartPageController.hasClients) return;
    _chartPageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    widget.chartTypeNotifier?.removeListener(_onExternalChartType);
    _chartPageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GrowthHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 別の子に切り替わったら、修正月齢表示はいったん暦月齢へ戻し、
    // 表示範囲もその子の年齢に合わせて選び直す。
    if (widget.child.id != oldWidget.child.id) {
      _useCorrectedAgeView = false;
      _selectedAgeRangeYears = _autoAgeRangeFor(widget.child);
    }
    if (widget.child.id != oldWidget.child.id ||
        !identical(widget.child.growthRecords, oldWidget.child.growthRecords)) {
      _reloadForChild();
    }
  }

  /// この子で修正月齢の切り替えが可能か（設定 ON かつ出産予定日あり）。
  bool get _canUseCorrectedAge =>
      _viewingChild.useCorrectedAge && _viewingChild.expectedBirthDate != null;

  /// 実際に修正月齢で描画中か。トグル ON かつ切り替え可能なときのみ true。
  bool get _isCorrectedView => _useCorrectedAgeView && _canUseCorrectedAge;

  void _reloadForChild() {
    // 表示用の並び替えは _sortedRecordPoints() が年齢昇順で行う。
    _records = List<GrowthRecord>.from(widget.child.growthRecords);
  }

  // ── グラフ構築 ──────────────────────────────────────────────────────────

  /// X 軸（年齢）の計算基準日。修正月齢モードでは出産予定日、
  /// 通常は実際の生年月日を返す。これ一点を切り替えるだけで、
  /// 記録点・X レンジ・現在年齢など全ての X 計算が連動して移動する。
  DateTime get _ageBaseDate => _isCorrectedView
      ? _viewingChild.expectedBirthDate!
      : _viewingChild.birthDate;

  double _ageAt(DateTime date) => date.difference(_ageBaseDate).inDays / 365.25;

  List<({DateTime date, double age, double? h, double? w})>
  _sortedRecordPoints() {
    final pts =
        _records
            .map(
              (r) => (
                date: r.date,
                age: _ageAt(r.date),
                h: r.heightCm,
                w: r.weightKg,
              ),
            )
            .where((r) => r.age >= 0)
            .toList()
          ..sort((a, b) => a.age.compareTo(b.age));
    return pts;
  }

  ({double minX, double maxX}) _dynamicXRange() {
    return (minX: 0.0, maxX: _selectedAgeRangeYears.toDouble());
  }

  /// 横軸（年齢チップ）ごとの縦グリッド間隔（chart 座標 = 年）。
  double _xAxisVerticalIntervalForMode(int ageYears) =>
      _kXAxisVerticalInterval[ageYears] ?? _kXAxisVerticalInterval[4]!;

  List<int> _xAxisTickLabelsForMode(int ageYears) =>
      _kXAxisTickLabels[ageYears] ?? _kXAxisTickLabels[4]!;

  String _xAxisUnitSuffixForMode(int ageYears) =>
      _kXAxisUnitSuffix[ageYears] ?? _kXAxisUnitSuffix[4]!;

  /// 横軸（年齢チップ）ごとのメモリ間隔・ラベル表示設定。
  /// ラベル配列・単位は [_kXAxisTickLabels] / [_kXAxisUnitSuffix] の定数を使用。
  ({double interval, int verticalLineCount}) _xAxisGridConfigForMode(
    int ageYears,
  ) {
    final labels = _xAxisTickLabelsForMode(ageYears);
    return (
      interval: _xAxisVerticalIntervalForMode(ageYears),
      verticalLineCount: labels.length,
    );
  }

  /// 年齢チップごとの固定 Y 軸描画範囲（身長・体重）。
  ({_AxisScale height, _AxisScale weight}) _fixedAxisPair(int ageYears) {
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
        return _fixedAxisPair(4);
    }
  }

  List<String> _fixedHeightYLabels(int ageYears) =>
      GraphLayoutConstants.heightLabelsForMode(ageYears);

  List<String> _fixedWeightYLabels(int ageYears) =>
      GraphLayoutConstants.weightLabelsForMode(ageYears);

  /// 年齢モードごとの横グリッド線本数（= Y 軸固定ラベル配列長）。
  int _yAxisDivisionCount(int ageYears) =>
      GraphLayoutConstants.yGridLineCountForMode(ageYears);

  double _yGridInterval(_AxisScale scale, int divisions) {
    if (divisions <= 1) return scale.plotMax - scale.plotMin;
    return (scale.plotMax - scale.plotMin) / (divisions - 1);
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Y 軸単位ラベル（(kg)/(cm)）：X 軸単位ラベルと同じサイズ・太さ、系列色のみ差別化。
  TextStyle _growthYAxisUnitTitleStyle(Color seriesColor, ColorScheme scheme) =>
      _xAxisUnitSuffixStyle(scheme).copyWith(color: seriesColor);

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

  TextStyle _yAxisNumberStyle(Color seriesColor) => TextStyle(
    fontSize: _growthChartAxisNumberFontSize,
    fontWeight: _growthChartAxisNumberFontWeight,
    height: 1.0,
    color: _seriesAxisLabelColor(seriesColor),
  );

  TextStyle _xAxisNumberStyle(ColorScheme scheme) => TextStyle(
    fontSize: _growthChartAxisNumberFontSize,
    fontWeight: _growthChartAxisNumberFontWeight,
    height: 1.0,
    color: scheme.onSurfaceVariant,
  );

  /// 成長曲線グラフの X 軸単位ラベル（「月齢（か月）」「年齢（歳）」）。
  TextStyle _xAxisUnitSuffixStyle(ColorScheme scheme) => _xAxisNumberStyle(
    scheme,
  ).copyWith(fontSize: 10 * _uiScale, fontWeight: FontWeight.w600);

  /// 下 X 軸数字行：各目盛りの中心を縦グリッド位置 i/(n-1) に固定。
  Widget _buildStaticXAxisNumbersRow({
    required List<int> tickLabels,
    required ColorScheme scheme,
  }) {
    final style = _xAxisNumberStyle(scheme);
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
                  final halfW = _measureTextWidth(context, text, style) / 2;
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
                        style: style,
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
    required List<int> tickLabels,
    required String unitSuffix,
    required ColorScheme scheme,
  }) {
    if (tickLabels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _growthChartXAxisNumbersHeight,
          child: _buildStaticXAxisNumbersRow(
            tickLabels: tickLabels,
            scheme: scheme,
          ),
        ),
        SizedBox(
          height: _growthChartXAxisUnitHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              unitSuffix,
              maxLines: 1,
              softWrap: false,
              style: _xAxisUnitSuffixStyle(scheme),
            ),
          ),
        ),
      ],
    );
  }

  /// 静的グラフクローム：プロット + X 軸。Y 数値・単位は fl_chart 内。
  Widget _buildStaticGrowthChartFrame({
    required ColorScheme scheme,
    required List<int> xTickLabels,
    required String xUnitSuffix,
    required Widget plotArea,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: plotArea),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: _growthChartYAxisReservedSize),
                  Expanded(
                    child: _buildStaticXAxisLabels(
                      tickLabels: xTickLabels,
                      unitSuffix: xUnitSuffix,
                      scheme: scheme,
                    ),
                  ),
                  SizedBox(width: _growthChartYAxisReservedSize),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 成長曲線 chart のグリッド（Y 固定分割 + X 目盛り数に同期した縦線）。
  FlGridData _buildGrowthGridData({
    required _AxisScale scale,
    required int yDivisions,
    required double minX,
    required double verticalInterval,
    required int verticalLineCount,
  }) {
    final horizontalInterval = _yGridInterval(scale, yDivisions);
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
      if (userSpots.isNotEmpty) _userLine(userSpots, seriesColor),
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

  /// SD 基準線の名札。帯の塗り・曲線に重なっても読めるよう半透明白の
  /// 下敷き＋太字で浮かせる（完全な白にせず、下の測定線がうっすら透ける）。
  /// 文字色は系列色（身長=青／体重=オレンジ）でどちらの基準か判別できる。
  /// 右端に縦に並ぶため、隣のラベルと干渉しないようコンパクトに保つ。
  Widget _sdInlineLabel(String text, Color seriesColor) => Container(
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
        fontSize: 7.5 * _uiScale,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: seriesColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    ),
  );

  /// 基準線は 1ヶ月刻み＋単調3次補間で点が十分滑らかなため折れ線で描く。
  /// ベジェ補間（isCurved: true）は制御点のはみ出しで帯が波打つため使わない。
  LineChartBarData _refLine(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 0.8,
        isCurved: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  LineChartBarData _userLine(
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

  /// グラフ本体。PageView で成長曲線 / SDスコアをスワイプ切り替え
  /// （切り替えはヘッダー右上のトグルとページ状態が連動）。
  /// 右下：修正月齢トグル（フローティング）。
  /// 最前面：データ点タップ時の詳細ボックス。
  Widget _buildChartArea(ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget? detailBox;
        if (_detailRecord != null && _detailPos != null) {
          final w = constraints.maxWidth;
          // ボックス（幅 ~170px）が左右にはみ出さないよう X をクランプし、
          // プロット上部でタップされた場合は点の下側に出す。
          final dx = _detailPos!.dx
              .clamp(90.0, math.max(90.0, w - 90.0))
              .toDouble();
          final showBelow = _detailPos!.dy < 130;
          detailBox = Positioned(
            left: dx,
            top: _detailPos!.dy + (showBelow ? 16.0 : -16.0),
            child: FractionalTranslation(
              translation: Offset(-0.5, showBelow ? 0 : -1),
              child: _buildRecordDetailBox(),
            ),
          );
        }

        return Stack(
          key: _chartAreaStackKey,
          clipBehavior: Clip.none,
          children: [
            PageView(
              controller: _chartPageController,
              onPageChanged: (index) {
                setState(() {
                  _chartPageIndex = index;
                  _detailRecord = null;
                  _detailPos = null;
                });
                // ヘッダー右上のトグル表示（AppShell 側）と同期する。
                widget.chartTypeNotifier?.value = index;
              },
              children: [
                KeyedSubtree(
                  key: ValueKey('growth_$_selectedAgeRangeYears'),
                  child: _buildOverlayGrowthChart(scheme),
                ),
                KeyedSubtree(
                  key: ValueKey('sd_$_selectedAgeRangeYears'),
                  child: _buildSdScoreChart(scheme),
                ),
              ],
            ),
            // SD スコア表示中のみ、系列色の凡例をグラフ上部中央に重ねる
            // （成長曲線側はグラフ内の「身長」「体重」の色文字で判別できる）。
            if (_chartPageIndex == 1)
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(child: _buildSdFloatingLegend()),
              ),
            if (_canUseCorrectedAge)
              Positioned(
                right: 6,
                bottom: _growthChartBottomAxisReservedSize + 6,
                child: _buildFloatingAgeModeSwitch(),
              ),
            // Stack の末尾 = 最前面。切り替えボタンと重なっても上に出る。
            ?detailBox,
          ],
        );
      },
    );
  }

  /// 表示年齢（X軸上限）を切り替える均等幅セグメントコントロール。
  Widget _buildAgeRangeSelector(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        height: 34 * _uiScale,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (final age in _kAgeRangeOptions)
              Expanded(
                child: _buildAgeRangeSegment(scheme: scheme, age: age),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeRangeSegment({
    required ColorScheme scheme,
    required int age,
  }) {
    final selected = _selectedAgeRangeYears == age;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!selected) {
            setState(() {
              _selectedAgeRangeYears = age;
              _detailRecord = null;
              _detailPos = null;
            });
          }
        },
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                // 「その年齢まで表示する」範囲選択であることが伝わるよう
                // 「～」を付ける（例：～1歳＝0〜1歳の範囲を表示）。
                '～$age歳',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11 * _uiScale,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 暦月齢 / 修正月齢 を切り替えるセグメント（グラフ右下フローティング）。
  Widget _buildFloatingAgeModeSwitch() {
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
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          selectedBackgroundColor: _correctedAccent.withValues(alpha: 0.20),
          selectedForegroundColor: _correctedAccent,
          foregroundColor: Colors.grey.shade700,
        ),
        segments: const [
          ButtonSegment<bool>(
            value: false,
            label: Text('暦月齢', maxLines: 1, softWrap: false),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('修正月齢', maxLines: 1, softWrap: false),
          ),
        ],
        selected: {_isCorrectedView},
        onSelectionChanged: (s) {
          setState(() {
            _useCorrectedAgeView = s.first;
            // 基準日が変わると年齢も変わるため、表示範囲を選び直す。
            _selectedAgeRangeYears = _autoAgeRangeFor(
              _viewingChild,
              corrected: s.first && _canUseCorrectedAge,
            );
            _detailRecord = null;
            _detailPos = null;
          });
        },
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
          color: _seriesAxisLabelColor(color),
        ),
      ),
    ],
  );

  /// SD スコアグラフ用のフローティング凡例（グラフ上部中央）。
  /// 成長曲線側はグラフ内の系列名ラベルで判別できるため出さない。
  Widget _buildSdFloatingLegend() {
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
            _legendEntry(_heightSeriesColor, '身長'),
            const SizedBox(width: 12),
            _legendEntry(_weightSeriesColor, '体重'),
            const SizedBox(width: 12),
            _legendEntry(const Color(0xFF66BB6A), '正常範囲(±2SD)'),
          ],
        ),
      ),
    );
  }

  /// 測定日からの詳細な年齢（例「3歳2か月9日」）を返す。
  /// 修正月齢表示中は出産予定日、それ以外は生年月日を基準にする（[_ageBaseDate]）。
  String _ageDetailLabel(DateTime date) {
    final base = _ageBaseDate;
    final d = DateTime(date.year, date.month, date.day);
    final b = DateTime(base.year, base.month, base.day);
    if (!d.isAfter(b)) return '0日';

    var years = d.year - b.year;
    var months = d.month - b.month;
    var days = d.day - b.day;
    if (days < 0) {
      months -= 1;
      // 1つ前の月の日数を借りる（DateTime(y, m, 0) はその前月末日）。
      days += DateTime(d.year, d.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    final sb = StringBuffer();
    if (years > 0) sb.write('$years歳');
    if (months > 0) sb.write('$monthsか月');
    sb.write('$days日');
    return sb.toString();
  }

  /// 記録詳細の本文（成長曲線・SDスコアの両グラフで共通）。
  /// 表示順：日付 → 詳細年齢 → 身長（SD）→ 体重（SD）。
  /// 未測定は「―」の行として必ず4行構成にし、日付もゼロ埋め固定桁に
  /// することで、タップする点によってボックスの大きさが変わらないようにする。
  TextSpan _recordDetailTextSpan(
    ({DateTime date, double age, double? h, double? w}) rec,
  ) {
    const dateStyle = TextStyle(
      fontSize: 12,
      color: Color(0xFF888888),
      height: 1.35,
    );
    const ageStyle = TextStyle(
      fontSize: 11,
      color: Color(0xFF888888),
      height: 1.35,
    );

    final isBoy = _viewingChild.gender == Gender.male;
    final months = rec.age * 12;

    // 値は系列色の太字、SD はその後ろに小さめのグレーで添える
    // （括弧付きだと行が長くなり折り返しの原因になるため）。
    // ±2SD を超える値のみ注意色にする。符号での色分け（＋青／−赤）は
    // 系列色と衝突するうえ「＋＝良い」という誤解を生むため行わない。
    List<TextSpan> valueSpans(
      double? v,
      String unit,
      bool isHeight, {
      required bool endWithNewline,
    }) {
      final suffix = endWithNewline ? '\n' : '';
      if (v == null || v <= 0) {
        return [
          TextSpan(
            text: '― $unit$suffix',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFBBBBBB),
            ),
          ),
        ];
      }
      final ref = isHeight
          ? GrowthLms2000.heightRef(isBoy: isBoy)
          : GrowthLms2000.weightRef(isBoy: isBoy);
      final z = ref.zScore(months, v);
      final zs = '${z >= 0 ? '+' : ''}${z.toStringAsFixed(1)}';
      final outOfRange = z.abs() > 2;
      return [
        TextSpan(
          // 体重は 10g 単位の端数があるときだけ小数2桁で表示する。
          text: '${isHeight ? v.toStringAsFixed(1) : formatWeightKg(v)} $unit ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHeight ? _heightSeriesColor : _weightSeriesColor,
          ),
        ),
        TextSpan(
          text: '${zs}SD$suffix',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: outOfRange
                ? const Color(0xFFD32F2F)
                : const Color(0xFF999999),
          ),
        ),
      ];
    }

    final d = rec.date;
    final dateStr =
        '${d.year}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';

    return TextSpan(
      text: '$dateStr\n',
      style: dateStyle,
      children: [
        TextSpan(text: '${_ageDetailLabel(rec.date)}\n', style: ageStyle),
        ...valueSpans(rec.h, 'cm', true, endWithNewline: true),
        ...valueSpans(rec.w, 'kg', false, endWithNewline: false),
      ],
    );
  }

  /// 記録詳細ボックス本体。Material の elevation でしっかり浮かせ、
  /// タップで閉じられるようにする。
  Widget _buildRecordDetailBox() {
    final rec = _detailRecord;
    if (rec == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _clearDetailBox,
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: _recordDetailTextSpan(rec),
          ),
        ),
      ),
    );
  }

  /// データ点タップ用の透明オーバーレイチャート（プロット領域と同一矩形）。
  Widget _buildTouchOverlayChart({
    required ColorScheme scheme,
    required double minX,
    required double maxX,
    required double horizontalInterval,
    required _AxisScale heightScale,
    required _AxisScale weightScale,
    required List<({DateTime date, double age, double? h, double? w})>
    recordPoints,
  }) {
    final pts = recordPoints
        .where((r) => r.age >= minX - 0.01 && r.age <= maxX + 0.01)
        .toList();

    double norm(double v, _AxisScale s) =>
        ((v - s.plotMin) / (s.plotMax - s.plotMin)).clamp(0.0, 1.0);

    // 未測定（0以下）の値は nullSpot にしてタップ対象から除外する。
    // リスト長と並びは pts と一致させ、spotIndex → pts の対応を保つ。
    final heightProxy = LineChartBarData(
      spots: [
        for (final p in pts)
          (p.h != null && p.h! > 0)
              ? FlSpot(p.age, norm(p.h!, heightScale))
              : FlSpot.nullSpot,
      ],
      color: _heightSeriesColor,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );
    final weightProxy = LineChartBarData(
      spots: [
        for (final p in pts)
          (p.w != null && p.w! > 0)
              ? FlSpot(p.age, norm(p.w!, weightScale))
              : FlSpot.nullSpot,
      ],
      color: _weightSeriesColor,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );

    return _wrapTouchChart(
      key: _growthTouchChartKey,
      chart: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: _growthChartYAxisPlaceholderTitles(
            horizontalInterval: horizontalInterval,
          ),
          // 選択中レコードの位置を示す縦線（詳細ボックスとセットで表示）。
          extraLinesData: ExtraLinesData(
            verticalLines: _selectedRecordVerticalLines(scheme),
          ),
          lineBarsData: [heightProxy, weightProxy],
          // 詳細表示は自前オーバーレイ（_buildRecordDetailBox）で行うため、
          // fl_chart の組み込みタッチ描画は使わずタップ検出のみ行う。
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchSpotThreshold: 18,
            touchCallback: (event, response) => _handleChartTouch(
              event,
              response,
              _growthTouchChartKey,
              (spot) => (spot.spotIndex >= 0 && spot.spotIndex < pts.length)
                  ? pts[spot.spotIndex]
                  : null,
            ),
          ),
        ),
        duration: const Duration(milliseconds: 150),
      ),
    );
  }

  /// タップ位置の座標変換用に GlobalKey を持たせるラッパー。
  Widget _wrapTouchChart({required GlobalKey key, required Widget chart}) =>
      KeyedSubtree(key: key, child: chart);

  /// 詳細表示中のデータ点位置を示す縦の指示線（両グラフ共通）。
  /// 詳細ボックスを自前オーバーレイ化した際に組み込みの指示線が
  /// 消えたため、選択中の X（年齢）に extraLines として描き直す。
  List<VerticalLine> _selectedRecordVerticalLines(ColorScheme scheme) => [
    if (_detailRecord != null)
      VerticalLine(
        x: _detailRecord!.age,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        strokeWidth: 1.2,
        dashArray: const [5, 3],
      ),
  ];

  /// 母子手帳スタイルの重ね合わせ。軸ラベルは LineChart 外側の Column/Row で描画し、
  /// プロット領域には水平グリッドと曲線のみを fl_chart に任せる。
  Widget _buildOverlayGrowthChart(ColorScheme scheme) {
    final xRange = _dynamicXRange();
    final minX = xRange.minX;
    final maxX = xRange.maxX;
    final recordPoints = _sortedRecordPoints();
    final isBoy = _viewingChild.gender == Gender.male;
    final xGrid = _xAxisGridConfigForMode(_selectedAgeRangeYears);
    final xTickLabels = _xAxisTickLabelsForMode(_selectedAgeRangeYears);
    final xUnitSuffix = _xAxisUnitSuffixForMode(_selectedAgeRangeYears);
    final yDivisions = _yAxisDivisionCount(_selectedAgeRangeYears);
    final weightLabels = _fixedWeightYLabels(_selectedAgeRangeYears);
    final heightLabels = _fixedHeightYLabels(_selectedAgeRangeYears);
    assert(
      weightLabels.length == yDivisions && heightLabels.length == yDivisions,
      'Y axis label count must match grid division count',
    );
    final fixedAxes = _fixedAxisPair(_selectedAgeRangeYears);
    final heightScale = fixedAxes.height;
    final weightScale = fixedAxes.weight;
    final horizontalInterval = _yGridInterval(heightScale, yDivisions);

    final heightSdCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: true);
    final weightSdCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: false);

    final heightChart = _buildHeightChart(
      scheme: scheme,
      minX: minX,
      maxX: maxX,
      yDivisions: yDivisions,
      xGrid: xGrid,
      recordPoints: recordPoints,
      heightScale: heightScale,
      weightLabels: weightLabels,
      heightLabels: heightLabels,
      horizontalInterval: horizontalInterval,
      sdCurves: heightSdCurves,
    );
    final weightChart = _buildWeightChart(
      minX: minX,
      maxX: maxX,
      recordPoints: recordPoints,
      weightScale: weightScale,
      horizontalInterval: horizontalInterval,
      sdCurves: weightSdCurves,
    );

    final plotBorder = Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      width: 0.5,
    );

    return _buildStaticGrowthChartFrame(
      scheme: scheme,
      xTickLabels: xTickLabels,
      xUnitSuffix: xUnitSuffix,
      plotArea: LayoutBuilder(
        builder: (context, constraints) {
          final yAxisReserved = _growthChartYAxisReservedSize;
          final plotWidth = constraints.maxWidth - yAxisReserved * 2;
          final plotSize = Size(plotWidth, constraints.maxHeight);

          Widget sdLabel(SdCurve curve, _AxisScale scale, Color seriesColor) {
            // どの線の名札か迷わないよう、ラベルは線上（右端）に直接載せる
            // （半透明の下敷きごしに線が通り抜けて見える）。
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
            final labelMaxWidth = 52.0 * _uiScale;
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
                child: _sdInlineLabel(curve.label, seriesColor),
              ),
            );
          }

          // 凡例行の代わりに、系列名をグラフ中央付近へ薄い色文字で直接書く。
          // 身長は +2.0SD 曲線の少し上、体重は -2.0SD 曲線の少し下に置くと
          // 帯と重ならず、どの帯がどの系列かも一目でわかる。
          Widget seriesNameLabel({
            required List<SdCurve> curves,
            required _AxisScale scale,
            required double anchorSd,
            required bool above,
            required String text,
            required Color seriesColor,
          }) {
            final curve = curves.firstWhere((c) => c.sd == anchorSd);
            final midX = (minX + maxX) / 2;
            final anchor = curve.spots.reduce(
              (a, b) => (a.x - midX).abs() <= (b.x - midX).abs() ? a : b,
            );
            final pos = _plotSpotToOffset(
              FlSpot(midX, anchor.y),
              plotSize,
              minX: minX,
              maxX: maxX,
              minY: scale.plotMin,
              maxY: scale.plotMax,
            );
            final fontSize = 14.0 * _uiScale;
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
                  seriesColor: _heightSeriesColor,
                ),
              if (weightSdCurves.isNotEmpty)
                seriesNameLabel(
                  curves: weightSdCurves,
                  scale: weightScale,
                  anchorSd: -2.0,
                  above: false,
                  text: '体重',
                  seriesColor: _weightSeriesColor,
                ),
              for (final curve in heightSdCurves)
                if (curve.showLabel && curve.spots.isNotEmpty)
                  sdLabel(curve, heightScale, _heightSeriesColor),
              for (final curve in weightSdCurves)
                if (curve.showLabel && curve.spots.isNotEmpty)
                  sdLabel(curve, weightScale, _weightSeriesColor),
              Positioned.fill(
                child: _buildTouchOverlayChart(
                  scheme: scheme,
                  minX: minX,
                  maxX: maxX,
                  horizontalInterval: horizontalInterval,
                  heightScale: heightScale,
                  weightScale: weightScale,
                  recordPoints: recordPoints,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 下層：身長・基準線・グリッド（横線+縦線）・左右 Y 軸ラベル。
  Widget _buildHeightChart({
    required ColorScheme scheme,
    required double minX,
    required double maxX,
    required int yDivisions,
    required ({double interval, int verticalLineCount}) xGrid,
    required List<({DateTime date, double age, double? h, double? w})>
    recordPoints,
    required _AxisScale heightScale,
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
      seriesColor: _heightSeriesColor,
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
          verticalInterval: xGrid.interval,
          verticalLineCount: xGrid.verticalLineCount,
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildGrowthChartYAxisTitlesData(
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
    required List<({DateTime date, double age, double? h, double? w})>
    recordPoints,
    required _AxisScale weightScale,
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
      seriesColor: _weightSeriesColor,
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
        titlesData: _growthChartYAxisPlaceholderTitles(
          horizontalInterval: horizontalInterval,
        ),
        lineBarsData: sd.bars,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// SD バンド（±2SD 等）の基準色。
  static const Color _sdBandColor = Color(0xFF66BB6A);

  Widget _sdYAxisLabelText(int v, ColorScheme scheme) {
    // 「+2.0」「-1.0」「0」表記（グラフ内の SD 値と桁を揃える）。
    final txt = v == 0 ? '0' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    final Color c;
    if (v == 0) {
      c = scheme.onSurface.withValues(alpha: 0.75);
    } else if (v == 2 || v == -2) {
      c = _sdBandColor;
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
  Widget _buildExternalSdYAxisColumn({
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

  /// SDスコア専用グラフ。軸ラベルは LineChart 外側で描画。
  Widget _buildSdScoreChart(ColorScheme scheme) {
    final xRange = _dynamicXRange();
    final minX = xRange.minX;
    final maxX = xRange.maxX;
    final xGrid = _xAxisGridConfigForMode(_selectedAgeRangeYears);
    final xTickLabels = _xAxisTickLabelsForMode(_selectedAgeRangeYears);
    final xUnitSuffix = _xAxisUnitSuffixForMode(_selectedAgeRangeYears);
    final recordPoints = _sortedRecordPoints();
    final isBoy = _viewingChild.gender == Gender.male;
    final hData = GrowthLms2000.heightRef(isBoy: isBoy);
    final wData = GrowthLms2000.weightRef(isBoy: isBoy);

    final hSpots = <FlSpot>[];
    final wSpots = <FlSpot>[];
    // タップ詳細（ツールチップ）で元レコードを引くための範囲内リスト。
    final inRange = <({DateTime date, double age, double? h, double? w})>[];
    var maxAbs = 2.0;
    for (final r in recordPoints) {
      if (r.age < minX - 0.01 || r.age > maxX + 0.01) continue;
      inRange.add(r);
      final months = r.age * 12;
      final h = r.h;
      final w = r.w;
      // 0以下は不正値扱いで点を打たない（zScore が 0 を返し平均線上に
      // 偽の点が出てしまうため）。
      if (h != null && h > 0) {
        final hz = hData.zScore(months, h);
        hSpots.add(FlSpot(r.age, hz));
        maxAbs = math.max(maxAbs, hz.abs());
      }
      if (w != null && w > 0) {
        final wz = wData.zScore(months, w);
        wSpots.add(FlSpot(r.age, wz));
        maxAbs = math.max(maxAbs, wz.abs());
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

    final chart = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: -yLimit,
        maxY: yLimit,
        clipData: const FlClipData.all(),
        // 成長曲線と同じタップ詳細（自前オーバーレイ）を表示する。
        // h/w の系列は null を飛ばして作るため spotIndex がレコード位置と
        // 一致せず、X（年齢）で引き当てる。
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchSpotThreshold: 18,
          touchCallback: (event, response) =>
              _handleChartTouch(event, response, _sdTouchChartKey, (spot) {
                for (final r in inRange) {
                  if ((r.age - spot.x).abs() < 1e-9) return r;
                }
                return null;
              }),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          verticalInterval: xGrid.interval,
          // 0.5 刻みで補助線を引く（±0.5・±1.5 なども読み取れるように）。
          horizontalInterval: 0.5,
          checkToShowVerticalLine: (x) {
            final rel = (x - minX) / xGrid.interval;
            final k = rel.round();
            return (rel - k).abs() < 0.08 &&
                k >= 0 &&
                k <= xGrid.verticalLineCount - 1;
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
        titlesData: _hiddenChartTitles,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            sdLine(2, dashed: true, color: _sdBandColor),
            sdLine(-2, dashed: true, color: _sdBandColor),
            sdLine(
              0,
              dashed: false,
              color: scheme.onSurface.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ],
          // 選択中レコードの位置を示す縦線（詳細ボックスとセットで表示）。
          verticalLines: _selectedRecordVerticalLines(scheme),
        ),
        // 注意：lineBarsData を空リストにすると fl_chart が基準線
        // （extraLinesData の ±2SD・平均線）ごと描画をスキップするため、
        // 表示範囲内に記録が無くても空スポットの系列を常に渡す。
        lineBarsData: [
          _userLine(hSpots, _heightSeriesColor),
          _userLine(wSpots, _weightSeriesColor),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );

    // 軸ラベル列はプロット領域と同じ高さに揃える必要があるため、
    // X 軸ラベル行（数字＋単位）ぶんの下余白を差し引く。
    final xAxisLabelsHeight =
        _growthChartXAxisNumbersHeight + _growthChartXAxisUnitHeight;
    Widget yAxisColumn(Alignment alignment) => SizedBox(
      width: _growthChartYAxisReservedSize,
      child: Padding(
        padding: EdgeInsets.only(bottom: xAxisLabelsHeight),
        child: _buildExternalSdYAxisColumn(
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
          // プロットの上へはみ出す。PageView にクリップされて欠けない
          // よう、プロット全体の上に半ラベルぶんの余白を確保する。
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
                            Positioned.fill(
                              child: _wrapTouchChart(
                                key: _sdTouchChartKey,
                                chart: chart,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStaticXAxisLabels(
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

  @override
  Widget build(BuildContext context) {
    // 子供切り替えタブと背景の色味は親（AppShell）が常時描画する。
    // ここではグラフ本体のみを返し、背景は透過させて親のテーマ色を活かす。
    final scheme = Theme.of(context).colorScheme;
    return _buildGrowthBody(scheme);
  }

  Widget _buildGrowthBody(ColorScheme scheme) {
    // カード枠（余白・角丸・クリップ・影）は State に依存しない完全に静的・
    // 決定論的なスタイルにする。影と角丸クリップは手組みの Container ではなく
    // Flutter 標準の Material（elevation=影 / shape=角丸+枠 / clipBehavior）で
    // 描画する。手組み Container + boxShadow + Clip.antiAlias は初回フレームで
    // 影やクリップが描かれず「上マージン0・角丸消失・タブに張り付き」に見える
    // 不整合の原因だった。Material は初回・再描画で同一に描画される。
    const cardRadius = BorderRadius.all(Radius.circular(16));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      // 大画面では横幅を制限して中央寄せする。高さは端末で頭打ちになるのに
      // 横だけ伸びると、成長曲線が横に引き伸ばされて傾き（成長ペース）が
      // 実際よりなだらかに見えてしまうため。
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: SizedBox.expand(
            child: Material(
              // 背景は常に白。修正月齢モードは枠線とトグルの選択状態で示す
              // （全面の色染めは目に付きすぎて見づらいためやめた）。
              color: Colors.white,
              elevation: 1.5,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: cardRadius,
                side: BorderSide(
                  color: _isCorrectedView
                      ? _correctedAccent.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 表示年齢（X軸上限）セレクター。
                  // 凡例行は廃止：成長曲線はグラフ内の「身長」「体重」色文字、
                  // SD スコアはフローティング凡例で系列を示す。
                  _buildAgeRangeSelector(scheme),
                  const SizedBox(height: 6),
                  Expanded(child: _buildChartArea(scheme)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
