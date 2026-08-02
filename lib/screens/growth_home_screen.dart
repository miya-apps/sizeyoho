import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';
import '../growth/growth_lms_2000.dart';
import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import '../widgets/growth_charts.dart';

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

  // ── グラフ本体の描画は lib/widgets/growth_charts.dart の共有ウィジェットに
  //    委譲する（書き出し画像と見た目を一本化）。ここにはタップ検出・
  //    詳細ボックスなど画面専用の層だけが残っている。

  /// 画面幅に応じた UI 拡大率（軸ラベル・年齢セレクター等に適用、最大1.3倍）。
  /// フォントと確保領域（reservedSize 等）を同率で拡大するため、
  /// 大画面でもラベルとグリッドの位置整合が保たれる。
  double get _uiScale => uiScaleForWidth(MediaQuery.sizeOf(context).width);

  GrowthChartStyle get _chartStyle => GrowthChartStyle(uiScale: _uiScale);

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
    return autoGrowthAgeRangeYears(base);
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
    // 別の子に切り替わったら、修正月齢表示はいったん暦月齢へ戻す。
    if (widget.child.id != oldWidget.child.id) {
      _useCorrectedAgeView = false;
    }
    // 子の切り替え・生年月日（出産予定日）の変更時は、年齢に合った表示範囲へ選び直す。
    final birthChanged =
        widget.child.birthDate != oldWidget.child.birthDate ||
        widget.child.expectedBirthDate != oldWidget.child.expectedBirthDate;
    if (widget.child.id != oldWidget.child.id || birthChanged) {
      _selectedAgeRangeYears = _autoAgeRangeFor(
        widget.child,
        corrected: _isCorrectedView,
      );
    }
    if (widget.child.id != oldWidget.child.id ||
        birthChanged ||
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
              const Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(child: SdChartLegend()),
              ),
            if (_canUseCorrectedAge)
              Positioned(
                right: 6,
                bottom: _chartStyle.bottomAxisReservedSize + 6,
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
            for (final age in kGrowthAgeRangeOptions)
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
            color: isHeight ? kGrowthHeightSeriesColor : kGrowthWeightSeriesColor,
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
    required GrowthAxisScale heightScale,
    required GrowthAxisScale weightScale,
    required List<({DateTime date, double age, double? h, double? w})>
    recordPoints,
  }) {
    final pts = recordPoints
        .where((r) => r.age >= minX - 0.01 && r.age <= maxX + 0.01)
        .toList();

    double norm(double v, GrowthAxisScale s) =>
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
      color: kGrowthHeightSeriesColor,
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
      color: kGrowthWeightSeriesColor,
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
          titlesData: growthYAxisPlaceholderTitles(
            horizontalInterval: horizontalInterval,
            reservedSize: _chartStyle.yAxisReservedSize,
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

  /// 母子手帳スタイルの重ね合わせ（描画は共有の [GrowthCurveChart]）。
  /// タップ検出レイヤーだけをこの画面で組み立てて重ねる。
  Widget _buildOverlayGrowthChart(ColorScheme scheme) {
    final recordPoints = _sortedRecordPoints();
    final fixedAxes = growthFixedAxisPair(_selectedAgeRangeYears);
    final yDivisions = growthYAxisDivisionCount(_selectedAgeRangeYears);
    final horizontalInterval = growthYGridInterval(
      fixedAxes.height,
      yDivisions,
    );

    return GrowthCurveChart(
      isBoy: _viewingChild.gender == Gender.male,
      recordPoints: recordPoints,
      ageRangeYears: _selectedAgeRangeYears,
      style: _chartStyle,
      plotForeground: _buildTouchOverlayChart(
        scheme: scheme,
        minX: 0,
        maxX: _selectedAgeRangeYears.toDouble(),
        horizontalInterval: horizontalInterval,
        heightScale: fixedAxes.height,
        weightScale: fixedAxes.weight,
        recordPoints: recordPoints,
      ),
    );
  }

  /// SDスコア専用グラフ（描画は共有の [SdScoreChart]）。
  /// タップ検出・選択中レコードの指示線だけをこの画面で注入する。
  Widget _buildSdScoreChart(ColorScheme scheme) {
    final recordPoints = _sortedRecordPoints();
    final maxX = _selectedAgeRangeYears.toDouble();
    // タップ詳細（ツールチップ）で元レコードを引くための範囲内リスト。
    final inRange = recordPoints
        .where((r) => r.age >= -0.01 && r.age <= maxX + 0.01)
        .toList();

    return SdScoreChart(
      isBoy: _viewingChild.gender == Gender.male,
      recordPoints: recordPoints,
      ageRangeYears: _selectedAgeRangeYears,
      style: _chartStyle,
      chartKey: _sdTouchChartKey,
      verticalLines: _selectedRecordVerticalLines(scheme),
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
