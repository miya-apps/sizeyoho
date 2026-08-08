import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app/app_info.dart';
import '../growth/growth_lms_2000.dart';
import '../growth/sd_curves.dart';
import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';

/// 医師に提示できる成長記録レポート（A4 PDF）を生成する。
///
/// 構成（アプリのグラフ画面と同じ見せ方に揃える）：
/// 1. 子供の基本情報（生年月日・性別・修正月齢設定・両親の身長・目標身長）
/// 2. 成長曲線（身長＝左軸・体重＝右軸の2軸合成、LMS 基準 ±2SD 帯付き）
/// 3. SDスコアの推移（±2SD の正常範囲と身長・体重の Z 値折れ線）
/// 4. 測定記録の一覧表（月齢・SDスコア付き、直近24件・2段組みで1枚に収める）
///
/// グラフは画面のスクショではなく PDF プリミティブで描き直すため、
/// 印刷しても線・文字が粗くならない。
class GrowthPdf {
  GrowthPdf._();

  // アプリのグラフと同じ系列色。
  static const _heightColor = PdfColor.fromInt(0xFF1565C0);
  static const _weightColor = PdfColor.fromInt(0xFFE65100);
  static const _sdBandColor = PdfColor.fromInt(0xFF66BB6A);
  static const _gridColor = PdfColor.fromInt(0xFFDDDDDD);
  static const _textGray = PdfColor.fromInt(0xFF666666);

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    if (_regular != null) return;
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/ZenKakuGothicNew-Regular.ttf'),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/ZenKakuGothicNew-Bold.ttf'),
    );
  }

  /// レポート PDF を生成してバイト列を返す。
  ///
  /// 横軸レンジは「全記録と現在年齢が収まる最小の表示モード」を自動で選ぶ。
  /// 受診時に最適な1枚になるよう、画面の表示状態には依存しない。
  ///
  /// [displayName] を渡すと、本文・タイトルの名前をその表記にする
  /// （プライバシー設定の「第一子」などの匿名表記に使う）。
  static Future<Uint8List> build({
    required ChildProfile child,
    String? displayName,
  }) async {
    await _ensureFonts();
    final name = displayName ?? child.displayName;

    final now = DateTime.now();
    final records = List<GrowthRecord>.from(child.growthRecords)
      ..sort((a, b) => a.date.compareTo(b.date));
    final useCorrected =
        child.useCorrectedAge && child.expectedBirthDate != null;

    // グラフの横軸レンジ：記録と現在年齢を含む最小の表示モードを選ぶ。
    final maxAgeYears = [
      child.chronologicalAgeInDaysAt(now) / 365.25,
      for (final r in records) child.effectiveAgeInDaysAt(r.date) / 365.25,
    ].reduce((a, b) => a > b ? a : b);
    final mode = _modeForAge(maxAgeYears);

    final doc = pw.Document(
      title: '成長記録レポート $name',
      producer: '$kAppName v$kAppVersion',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 32),
        theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '基準値：日本小児内分泌学会 標準値（2000年度調査・LMS法）'
                      '／本資料は保護者がアプリで記録した参考情報です',
                      style: const pw.TextStyle(fontSize: 7, color: _textGray),
                    ),
                    pw.Text(
                      '本アプリは医療機器ではなく、本資料は診断を目的とした'
                      'ものではありません。判断は医師にご相談ください。'
                      '／作成アプリ：$kAppName v$kAppVersion',
                      style: const pw.TextStyle(fontSize: 7, color: _textGray),
                    ),
                  ],
                ),
              ),
              pw.Text(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _textGray),
              ),
            ],
          ),
        ),
        // 記録一覧が2段組みフル（24件）でも必ず A4 1枚に収まるよう、
        // グラフの高さ・セクション間の余白は詰めてある（変更時は
        // growth_pdf_test の1ページ検証が落ちないこと）。
        build: (ctx) => [
          _buildHeader(child, name, now, useCorrected),
          pw.SizedBox(height: 10),
          _buildGrowthChart(
            child: child,
            records: records,
            mode: mode,
            useCorrected: useCorrected,
          ),
          pw.SizedBox(height: 10),
          _buildSdScoreChart(
            child: child,
            records: records,
            mode: mode,
            useCorrected: useCorrected,
          ),
          pw.SizedBox(height: 10),
          _buildRecordsTable(child, records, useCorrected),
        ],
      ),
    );

    return doc.save();
  }

  // ── 基本情報ヘッダー ──────────────────────────────────────────────

  static pw.Widget _buildHeader(
    ChildProfile child,
    String name,
    DateTime now,
    bool useCorrected,
  ) {
    final mph = child.midParentalHeightCm;

    pw.Widget item(String label, String value) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 64,
              child: pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8.5, color: _textGray),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
            ),
          ],
        );

    String heightOrDash(double? v) =>
        v == null ? '未入力' : '${_trimZero(v)} cm';

    final left = <pw.Widget>[
      item('生年月日', '${_formatDate(child.birthDate)}'
          '（${_ageLabelFrom(child.birthDate, now)}）'),
      item('性別', child.gender.label),
      if (useCorrected) ...[
        item('出産予定日', _formatDate(child.expectedBirthDate!)),
        item('修正月齢', _ageLabelFrom(child.expectedBirthDate!, now)),
      ],
    ];
    final right = <pw.Widget>[
      item('父の身長', heightOrDash(child.fatherHeightCm)),
      item('母の身長', heightOrDash(child.motherHeightCm)),
      if (mph != null)
        item('目標身長', '${mph.toStringAsFixed(1)} cm（両親の身長より算出）'),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '成長記録レポート',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF333333),
              ),
            ),
            pw.Spacer(),
            pw.Text(
              '作成日：${_formatDate(now)}',
              style: const pw.TextStyle(fontSize: 8.5, color: _textGray),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _gridColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final w in left)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: w,
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final w in right)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: w,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── チャート共通設定 ─────────────────────────────────────────────

  /// 表示モードの選択肢（アプリの年齢セレクターと同じ）。
  static const _kModes = [1, 2, 4, 8, 12, 18];

  /// 記録と年齢を含む最小の表示モード。
  /// 境界（ちょうど1歳など）はアプリの自動選択と同じく1段広い範囲にする。
  static int _modeForAge(double ageYears) {
    for (final m in _kModes) {
      if (ageYears < m) return m;
    }
    return 18;
  }

  /// モード別 Y 軸レンジ（アプリのグラフと同じ値）。
  static ({double hMin, double hMax, double wMin, double wMax}) _yRange(
    int mode,
  ) =>
      switch (mode) {
        // 1歳・12歳は身長帯と体重帯が接近するため、レンジを広げて
        // 身長を上段・体重を下段に分離する（アプリのグラフと同じ値）。
        1 => (hMin: 5, hMax: 90, wMin: 0, wMax: 17),
        2 => (hMin: 30, hMax: 105, wMin: 0, wMax: 30),
        4 => (hMin: 30, hMax: 115, wMin: 0, wMax: 34),
        8 => (hMin: 0, hMax: 150, wMin: 0, wMax: 75),
        12 => (hMin: -20, hMax: 180, wMin: 0, wMax: 100),
        _ => (hMin: 30, hMax: 210, wMin: 0, wMax: 180),
      };

  /// モード別 Y 軸グリッド間隔。
  static double _yStep(int mode, bool isHeight) => isHeight
      ? (mode <= 4 ? 5 : 10)
      : switch (mode) {
          1 => 1,
          2 || 4 => 2,
          8 || 12 => 5,
          _ => 10,
        };

  /// モード別 X 軸目盛り（月数リストと単位）。
  static ({List<int> tickMonths, bool labelInMonths}) _xTicks(int mode) =>
      switch (mode) {
        1 => (
            tickMonths: [for (var m = 0; m <= 12; m += 1) m],
            labelInMonths: true,
          ),
        2 => (
            tickMonths: [for (var m = 0; m <= 24; m += 2) m],
            labelInMonths: true,
          ),
        4 => (
            tickMonths: [for (var m = 0; m <= 48; m += 4) m],
            labelInMonths: true,
          ),
        8 => (
            tickMonths: [for (var m = 0; m <= 96; m += 12) m],
            labelInMonths: false,
          ),
        12 => (
            tickMonths: [for (var m = 0; m <= 144; m += 12) m],
            labelInMonths: false,
          ),
        _ => (
            tickMonths: [for (var m = 0; m <= 216; m += 24) m],
            labelInMonths: false,
          ),
      };

  /// 記録から系列点（X=年齢[年]・修正月齢設定に追従）を取り出す。
  static List<({double x, double y})> _seriesPoints(
    ChildProfile child,
    List<GrowthRecord> records,
    double xMaxYears, {
    required bool isHeight,
  }) =>
      [
        for (final r in records)
          if ((isHeight ? r.heightCm : r.weightKg) != null)
            if (child.effectiveAgeInDaysAt(r.date) >= 0 &&
                child.effectiveAgeInDaysAt(r.date) / 365.25 <= xMaxYears)
              (
                x: child.effectiveAgeInDaysAt(r.date) / 365.25,
                y: (isHeight ? r.heightCm : r.weightKg)!,
              ),
      ];

  /// X 軸の目盛りラベル・単位（Positioned）を生成する共通処理。
  static List<pw.Widget> _xAxisLabels({
    required ({List<int> tickMonths, bool labelInMonths}) xTicks,
    required double Function(double years) cx,
    required double axisTopY,
  }) =>
      [
        for (final m in xTicks.tickMonths)
          pw.Positioned(
            left: cx(m / 12) - 10,
            top: axisTopY + 3,
            child: pw.SizedBox(
              width: 20,
              child: pw.Text(
                xTicks.labelInMonths ? '$m' : '${m ~/ 12}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
              ),
            ),
          ),
        pw.Positioned(
          right: 0,
          top: axisTopY + 12,
          child: pw.Text(
            xTicks.labelInMonths ? '月齢（か月）' : '年齢（歳）',
            style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
          ),
        ),
      ];

  // ── 成長曲線チャート（身長＋体重の2軸合成・ベクター描画） ────────

  static pw.Widget _buildGrowthChart({
    required ChildProfile child,
    required List<GrowthRecord> records,
    required int mode,
    required bool useCorrected,
  }) {
    const totalW = 515.0;
    const totalH = 236.0;
    const insetL = 34.0; // 左：身長軸ラベル
    const insetR = 34.0; // 右：体重軸ラベル
    const insetT = 6.0;
    const insetB = 26.0; // X 軸ラベル + 単位
    const plotW = totalW - insetL - insetR;
    const plotH = totalH - insetT - insetB;

    final xMaxYears = mode.toDouble();
    final range = _yRange(mode);
    final xTicks = _xTicks(mode);
    final isBoy = child.gender == Gender.male;

    final heightCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: true);
    final weightCurves = SdCurves.forSeries(isBoy: isBoy, isHeight: false);
    final heightPoints =
        _seriesPoints(child, records, xMaxYears, isHeight: true);
    final weightPoints =
        _seriesPoints(child, records, xMaxYears, isHeight: false);

    // チャート座標 → キャンバス座標（PDF は原点が左下・Y 上向き）。
    double cx(double years) => insetL + (years / xMaxYears) * plotW;
    double cyH(double v) =>
        insetB + ((v - range.hMin) / (range.hMax - range.hMin)) * plotH;
    double cyW(double v) =>
        insetB + ((v - range.wMin) / (range.wMax - range.wMin)) * plotH;
    // キャンバス Y → レイアウト（Positioned）の top 値。
    double topOf(double canvasY) => totalH - canvasY;

    List<({double x, double y})> curvePoints(SdCurve c) => [
          for (final s in c.spots)
            if (s.x <= xMaxYears + 1e-9) (x: s.x, y: s.y),
        ];

    void polyline(
      PdfGraphics canvas,
      List<({double x, double y})> pts,
      double Function(double) cy,
    ) {
      if (pts.isEmpty) return;
      canvas.moveTo(cx(pts.first.x), cy(pts.first.y));
      for (final p in pts.skip(1)) {
        canvas.lineTo(cx(p.x), cy(p.y));
      }
    }

    void drawSeries(
      PdfGraphics canvas,
      List<SdCurve> curves,
      List<({double x, double y})> points,
      double Function(double) cy,
      PdfColor seriesColor,
    ) {
      // 基準線・帯はアプリと同じく「薄い系列色」（身長=青系／体重=橙系）。
      // 実測線が主役になるよう控えめな濃度に抑える。
      // ※canvas 直描画はアルファを解釈しないため、白との混色で薄色を作る。
      // 濃度・太さはアプリの基準線（alpha 0.30・太さ 0.8・全て実線）と同一。
      final refLineColor = _tint(seriesColor, 0.30);

      void fillBand(double sdTop, double sdBottom, PdfColor fill) {
        final top = curvePoints(curves.firstWhere((c) => c.sd == sdTop));
        final bottom = curvePoints(curves.firstWhere((c) => c.sd == sdBottom));
        if (top.isEmpty || bottom.isEmpty) return;
        canvas.setFillColor(fill);
        canvas.moveTo(cx(top.first.x), cy(top.first.y));
        for (final p in top.skip(1)) {
          canvas.lineTo(cx(p.x), cy(p.y));
        }
        for (final p in bottom.reversed) {
          canvas.lineTo(cx(p.x), cy(p.y));
        }
        canvas.closePath();
        canvas.fillPath();
      }

      // 帯の塗りはアプリと同じ二段の濃淡：±2SD 全体を薄く塗り、
      // 内側の ±1SD をひと回り濃く重ねる。
      fillBand(2.0, -2.0, _tint(seriesColor, 0.08));
      fillBand(1.0, -1.0, _tint(seriesColor, 0.18));
      // SD 基準線（アプリと同じく全て同太・実線）
      canvas.setStrokeColor(refLineColor);
      canvas.setLineWidth(0.8);
      for (final c in curves) {
        polyline(canvas, curvePoints(c), cy);
        canvas.strokePath();
      }
      // 記録の折れ線と点
      if (points.isNotEmpty) {
        canvas.setStrokeColor(seriesColor);
        canvas.setLineWidth(1.4);
        polyline(canvas, points, cy);
        canvas.strokePath();
        canvas.setFillColor(seriesColor);
        for (final p in points) {
          canvas.drawEllipse(cx(p.x), cy(p.y), 2.2, 2.2);
          canvas.fillPath();
        }
      }
    }

    void painter(PdfGraphics canvas, PdfPoint size) {
      // 横グリッド（身長軸基準）・縦グリッド
      canvas.setLineWidth(0.5);
      canvas.setStrokeColor(_gridColor);
      final hStep = _yStep(mode, true);
      for (var v = range.hMin; v <= range.hMax + 1e-9; v += hStep) {
        canvas.moveTo(insetL, cyH(v));
        canvas.lineTo(insetL + plotW, cyH(v));
      }
      for (final m in xTicks.tickMonths) {
        final x = cx(m / 12);
        canvas.moveTo(x, insetB);
        canvas.lineTo(x, insetB + plotH);
      }
      canvas.strokePath();

      // 体重（下層）→ 身長（上層）の順に重ねる（アプリと同じ）。
      // 基準帯・曲線・実測線が枠の外へはみ出さないよう、
      // プロット領域でクリップして描く（アプリの clipData と同じ扱い）。
      canvas.saveContext();
      canvas.drawRect(insetL, insetB, plotW, plotH);
      canvas.clipPath();
      drawSeries(canvas, weightCurves, weightPoints, cyW, _weightColor);
      drawSeries(canvas, heightCurves, heightPoints, cyH, _heightColor);
      canvas.restoreContext();

      // プロット枠
      canvas.setStrokeColor(const PdfColor.fromInt(0xFF999999));
      canvas.setLineWidth(0.8);
      canvas.drawRect(insetL, insetB, plotW, plotH);
      canvas.strokePath();
    }

    // 軸ラベル（Positioned テキスト）
    final labels = <pw.Widget>[];
    final hStep = _yStep(mode, true);
    for (var v = range.hMin; v <= range.hMax + 1e-9; v += hStep) {
      // 分離用に広げたレンジのマイナス域には数値を出さない。
      if (v < 0) continue;
      labels.add(
        pw.Positioned(
          left: 0,
          top: topOf(cyH(v)) - 4,
          child: pw.SizedBox(
            width: insetL - 4,
            child: pw.Text(
              _trimZero(v),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 6.5, color: _heightColor),
            ),
          ),
        ),
      );
    }
    final wStep = _yStep(mode, false);
    for (var v = range.wMin; v <= range.wMax + 1e-9; v += wStep) {
      labels.add(
        pw.Positioned(
          left: insetL + plotW + 4,
          top: topOf(cyW(v)) - 4,
          child: pw.SizedBox(
            width: insetR - 6,
            child: pw.Text(
              _trimZero(v),
              style: const pw.TextStyle(fontSize: 6.5, color: _weightColor),
            ),
          ),
        ),
      );
    }
    labels.addAll(
      _xAxisLabels(xTicks: xTicks, cx: cx, axisTopY: topOf(insetB)),
    );

    // SD ラベルはアプリと同じく5本（±2SD・±1SD・平均）すべてに付け、
    // 対象の線上に直接載せる（下敷きは半透明にして線がラベルの下を
    // 通り抜けて見える＝どの線の名札か迷わない）。
    // 文字色は系列色（身長=青／体重=オレンジ）でどちらの基準か判別できる。
    // 曲線が縦に詰まるモード（例：12歳表示の身長帯）ではラベル同士が
    // 重なるため、上から順に最小間隔を保つよう位置をずらして解消する。
    const labelGap = 5.5; // ラベル箱の高さ相当（フォント4pt＋余白）
    for (final (curves, cy, color) in [
      (heightCurves, cyH, _heightColor),
      (weightCurves, cyW, _weightColor),
    ]) {
      final entries = <({SdCurve c, double top})>[
        for (final c in curves)
          if (curvePoints(c).isNotEmpty)
            (c: c, top: topOf(cy(curvePoints(c).last.y)) - 3.5),
      ]..sort((a, b) => a.top.compareTo(b.top));
      final tops = <double>[];
      for (final e in entries) {
        final minTop = tops.isEmpty ? e.top : tops.last + labelGap;
        tops.add(e.top < minTop ? minTop : e.top);
      }
      // 右詰め：文字数が違うラベル（「平均」と「+2.0SD」）でも
      // 右端がプロット右端の少し内側にそろう。
      for (var i = 0; i < entries.length; i++) {
        final c = entries[i].c;
        labels.add(
          pw.Positioned(
            right: insetR + 2,
            top: tops[i],
            // 見た目はアプリの _sdInlineLabel と同一比率：
            // フォント7.5px時に radius 3・枠0.5・padding 2.5/0.5 なので、
            // フォント4pt ではその 4/7.5 倍に揃える。
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: const PdfColor(1, 1, 1, 0.72),
                border: pw.Border.all(
                  color: PdfColor(color.red, color.green, color.blue, 0.35),
                  width: 0.27,
                ),
                borderRadius: pw.BorderRadius.circular(1.6),
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 1.33,
                vertical: 0.27,
              ),
              child: pw.Text(
                c.sd == 0 ? '平均' : c.label,
                style: pw.TextStyle(
                  fontSize: 4,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                  lineSpacing: 0,
                ),
              ),
            ),
          ),
        );
      }
    }

    final ageNote = useCorrected ? '（横軸は修正月齢基準）' : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '成長曲線$ageNote',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 10),
            _legendDot(_heightColor, '身長（左軸 cm）'),
            pw.SizedBox(width: 8),
            _legendDot(_weightColor, '体重（右軸 kg）'),
            pw.Spacer(),
            pw.Text(
              '基準線：±2SD・±1SD・平均／塗り：標準範囲（濃＝±1SD・淡＝±2SD）',
              style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.SizedBox(
          width: totalW,
          height: totalH,
          child: pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.CustomPaint(
                  size: const PdfPoint(totalW, totalH),
                  painter: painter,
                ),
              ),
              ...labels,
            ],
          ),
        ),
      ],
    );
  }

  // ── SDスコア推移チャート ─────────────────────────────────────────

  static pw.Widget _buildSdScoreChart({
    required ChildProfile child,
    required List<GrowthRecord> records,
    required int mode,
    required bool useCorrected,
  }) {
    const totalW = 515.0;
    const totalH = 150.0;
    const insetL = 34.0;
    const insetR = 34.0;
    const insetT = 6.0;
    const insetB = 26.0;
    const plotW = totalW - insetL - insetR;
    const plotH = totalH - insetT - insetB;

    final xMaxYears = mode.toDouble();
    final xTicks = _xTicks(mode);
    final isBoy = child.gender == Gender.male;
    final heightRef = GrowthLms2000.heightRef(isBoy: isBoy);
    final weightRef = GrowthLms2000.weightRef(isBoy: isBoy);

    // 記録から SD スコア点列を作る（アプリの SD グラフと同じ）。
    final hPoints = <({double x, double y})>[];
    final wPoints = <({double x, double y})>[];
    var maxAbs = 2.0;
    for (final r in records) {
      final days = child.effectiveAgeInDaysAt(r.date);
      if (days < 0) continue;
      final years = days / 365.25;
      if (years > xMaxYears) continue;
      final months = years * 12;
      final h = r.heightCm;
      final w = r.weightKg;
      if (h != null) {
        final z = heightRef.zScore(months, h);
        hPoints.add((x: years, y: z));
        maxAbs = math.max(maxAbs, z.abs());
      }
      if (w != null) {
        final z = weightRef.zScore(months, w);
        wPoints.add((x: years, y: z));
        maxAbs = math.max(maxAbs, z.abs());
      }
    }
    // 基本は ±3.0 固定。実測が外れる場合のみ ±4.0 へ拡張（アプリと同じ）。
    final yLimit = maxAbs <= 3.0 ? 3.0 : 4.0;

    double cx(double years) => insetL + (years / xMaxYears) * plotW;
    double cy(double z) => insetB + ((z + yLimit) / (2 * yLimit)) * plotH;
    double topOf(double canvasY) => totalH - canvasY;

    void polyline(PdfGraphics canvas, List<({double x, double y})> pts) {
      if (pts.isEmpty) return;
      canvas.moveTo(cx(pts.first.x), cy(pts.first.y.clamp(-yLimit, yLimit)));
      for (final p in pts.skip(1)) {
        canvas.lineTo(cx(p.x), cy(p.y.clamp(-yLimit, yLimit)));
      }
    }

    void painter(PdfGraphics canvas, PdfPoint size) {
      // グリッド（整数 SD ごとの横線・X 目盛りの縦線）
      canvas.setLineWidth(0.5);
      canvas.setStrokeColor(_gridColor);
      for (var z = -yLimit; z <= yLimit + 1e-9; z += 1) {
        canvas.moveTo(insetL, cy(z));
        canvas.lineTo(insetL + plotW, cy(z));
      }
      for (final m in xTicks.tickMonths) {
        canvas.moveTo(cx(m / 12), insetB);
        canvas.lineTo(cx(m / 12), insetB + plotH);
      }
      canvas.strokePath();

      // 平均（0）の実線
      canvas.setStrokeColor(const PdfColor.fromInt(0xFF888888));
      canvas.setLineWidth(0.8);
      canvas.moveTo(insetL, cy(0));
      canvas.lineTo(insetL + plotW, cy(0));
      canvas.strokePath();

      // 正常範囲 ±2SD の破線（緑・アプリと同じ）
      canvas.setStrokeColor(_sdBandColor);
      canvas.setLineWidth(1.0);
      canvas.setLineDashPattern(<int>[4, 3]);
      for (final z in const [2.0, -2.0]) {
        canvas.moveTo(insetL, cy(z));
        canvas.lineTo(insetL + plotW, cy(z));
      }
      canvas.strokePath();
      canvas.setLineDashPattern(<int>[]);

      // 身長・体重の SD 折れ線と点
      for (final (pts, color) in [
        (wPoints, _weightColor),
        (hPoints, _heightColor),
      ]) {
        if (pts.isEmpty) continue;
        canvas.setStrokeColor(color);
        canvas.setLineWidth(1.4);
        polyline(canvas, pts);
        canvas.strokePath();
        canvas.setFillColor(color);
        for (final p in pts) {
          canvas.drawEllipse(
            cx(p.x),
            cy(p.y.clamp(-yLimit, yLimit)),
            2.2,
            2.2,
          );
          canvas.fillPath();
        }
      }

      // プロット枠
      canvas.setStrokeColor(const PdfColor.fromInt(0xFF999999));
      canvas.setLineWidth(0.8);
      canvas.drawRect(insetL, insetB, plotW, plotH);
      canvas.strokePath();
    }

    final labels = <pw.Widget>[];
    for (var z = -yLimit; z <= yLimit + 1e-9; z += 1) {
      // アプリの外付け軸と同じ「+2.0」形式でそろえる。
      final text = z == 0
          ? '0'
          : (z > 0 ? '+${z.toStringAsFixed(1)}' : z.toStringAsFixed(1));
      labels.add(
        pw.Positioned(
          left: 0,
          top: topOf(cy(z)) - 4,
          child: pw.SizedBox(
            width: insetL - 4,
            child: pw.Text(
              text,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
            ),
          ),
        ),
      );
    }
    // ±2SD ラベル（右端・緑）
    for (final z in const [2.0, -2.0]) {
      labels.add(
        pw.Positioned(
          left: insetL + plotW + 4,
          top: topOf(cy(z)) - 4,
          child: pw.Text(
            z > 0 ? '+2.0SD' : '-2.0SD',
            style: const pw.TextStyle(fontSize: 6, color: _sdBandColor),
          ),
        ),
      );
    }
    labels.addAll(
      _xAxisLabels(xTicks: xTicks, cx: cx, axisTopY: topOf(insetB)),
    );

    final ageNote = useCorrected ? '（横軸は修正月齢基準）' : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'SDスコアの推移$ageNote',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 10),
            _legendDot(_heightColor, '身長 SD'),
            pw.SizedBox(width: 8),
            _legendDot(_weightColor, '体重 SD'),
            pw.Spacer(),
            pw.Text(
              '緑破線：正常範囲（±2SD）／実線：平均（0）',
              style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.SizedBox(
          width: totalW,
          height: totalH,
          child: pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.CustomPaint(
                  size: const PdfPoint(totalW, totalH),
                  painter: painter,
                ),
              ),
              ...labels,
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _legendDot(PdfColor color, String label) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 7, height: 7, color: color),
          pw.SizedBox(width: 3),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: _textGray),
          ),
        ],
      );

  // ── 記録一覧表 ────────────────────────────────────────────────

  /// 記録一覧の1段あたりの最大行数。2段組みでこの2倍が掲載上限。
  /// グラフ2枚と合わせてレポートが A4 1枚に収まる行数にしてある。
  static const int _tableRowsPerColumn = 12;

  static pw.Widget _buildRecordsTable(
    ChildProfile child,
    List<GrowthRecord> allRecords,
    bool useCorrected,
  ) {
    if (allRecords.isEmpty) {
      return pw.Text(
        '測定記録はまだありません。',
        style: const pw.TextStyle(fontSize: 9, color: _textGray),
      );
    }

    // 日付昇順で渡されるので、末尾（直近）から最大件数だけ載せる。
    const maxRows = _tableRowsPerColumn * 2;
    final truncated = allRecords.length > maxRows;
    final records = truncated
        ? allRecords.sublist(allRecords.length - maxRows)
        : allRecords;

    final isBoy = child.gender == Gender.male;
    final heightRef = GrowthLms2000.heightRef(isBoy: isBoy);
    final weightRef = GrowthLms2000.weightRef(isBoy: isBoy);

    // 値と SD をひとつのセルにまとめる（2段組みで幅が半分になるため）。
    String cellText(double? value, bool isHeight, GrowthRecord r) {
      if (value == null) return '—';
      final months = child.effectiveAgeInDaysAt(r.date) / 365.25 * 12;
      if (months < 0) return _trimZero(value);
      final z = (isHeight ? heightRef : weightRef).zScore(months, value);
      final s = '${z >= 0 ? '+' : ''}${z.toStringAsFixed(1)}';
      return '${_trimZero(value)}（$s）';
    }

    // 月齢は1列に絞る：修正月齢の子は SD 計算と同じ修正月齢を載せる。
    final ageBase =
        useCorrected ? child.expectedBirthDate! : child.birthDate;
    final headers = [
      '測定日',
      useCorrected ? '修正月齢' : '月齢',
      '身長 cm（SD）',
      '体重 kg（SD）',
    ];

    List<List<String>> rowsOf(List<GrowthRecord> part) => [
          for (final r in part)
            [
              _formatDate(r.date),
              _ageLabelFrom(ageBase, r.date),
              cellText(r.heightCm, true, r),
              cellText(r.weightKg, false, r),
            ],
        ];

    // 1段に収まる件数なら無理に分割しない（左寄せの半幅で1段表示）。
    // 収まらないときだけ、左の段を上から下へ読み、続きが右の段になる。
    final single = records.length <= _tableRowsPerColumn;
    final splitAt = single ? records.length : (records.length + 1) ~/ 2;
    final left = records.sublist(0, splitAt);
    final right = records.sublist(splitAt);

    pw.Widget table(List<GrowthRecord> part) => pw.TableHelper.fromTextArray(
          headers: headers,
          data: rowsOf(part),
          headerStyle: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF0F0F0),
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
          },
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 1.5,
          ),
          border: pw.TableBorder.all(color: _gridColor, width: 0.5),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '測定記録一覧${useCorrected ? '（月齢・SD は修正月齢基準）' : ''}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            if (truncated)
              pw.Text(
                '※直近 $maxRows 件を掲載（全 ${allRecords.length} 件の推移は'
                'グラフに反映）',
                style: const pw.TextStyle(fontSize: 6.5, color: _textGray),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: table(left)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: single ? pw.SizedBox() : table(right)),
          ],
        ),
      ],
    );
  }

  // ── 共通フォーマッタ ─────────────────────────────────────────

  static String _formatDate(DateTime d) => '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  /// 整数なら小数点なし、0.1 単位なら 1 桁、10g 単位の端数があれば 2 桁表示。
  static String _trimZero(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final centi = (v * 100).round();
    return centi % 10 == 0 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
  }

  /// 白と [color] の混色（t=0 で白、1 で元色）。
  /// PdfGraphics の直描画はアルファを解釈しないため、薄色はこれで作る。
  static PdfColor _tint(PdfColor color, double t) => PdfColor(
        1 - (1 - color.red) * t,
        1 - (1 - color.green) * t,
        1 - (1 - color.blue) * t,
      );

  /// 基準日からの年齢を「Y歳Mか月」（1歳未満は「Mか月」）で表す。
  static String _ageLabelFrom(DateTime base, DateTime date) {
    var months = (date.year - base.year) * 12 + (date.month - base.month);
    if (date.day < base.day) months--;
    if (months < 0) return '—';
    final y = months ~/ 12;
    final m = months % 12;
    return y > 0 ? '$y歳$mか月' : '$mか月';
  }
}
