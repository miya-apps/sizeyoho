import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import 'growth_lms_2000.dart';
import 'lms_reference.dart';

/// 期間ごとの身長成長サマリー（計算結果）。
class GrowthPeriodSummary {
  const GrowthPeriodSummary({
    required this.hasData,
    this.start,
    this.end,
    this.periodLabel,
    this.dateRangeLabel,
    this.heightDeltaCm,
    this.cmPerYear,
    this.sdStart,
    this.sdEnd,
  });

  /// 比較に十分なデータがあるか。
  final bool hasData;

  /// 期間の開始側（古い方）の記録。
  final GrowthRecord? start;

  /// 期間の終了側（新しい方＝基準日）の記録。
  final GrowthRecord? end;

  /// 期間ラベル（例：1年2ヶ月15日）。内部計算用。
  final String? periodLabel;

  /// 表示用の日付レンジ（例：2025/08/15 〜 2026/06/26（10ヶ月11日））。
  final String? dateRangeLabel;

  /// 身長の伸び（cm）。正なら成長。
  final double? heightDeltaCm;

  /// 年間換算の成長ペース（cm/年）。
  final double? cmPerYear;

  final double? sdStart;
  final double? sdEnd;

  static const noData = GrowthPeriodSummary(hasData: false);
}

/// 身長成長ペースの自動計算（直近1年）。
class GrowthPeriodSummaryCalculator {
  GrowthPeriodSummaryCalculator._();

  static const _daysPerYear = 365.25;

  /// 基準日（最新記録）から [daysBack] 日前に最も近い記録との比較結果。
  static GrowthPeriodSummary compute({
    required ChildProfile child,
    required List<GrowthRecord> records,
    required int daysBack,
  }) {
    final withHeight = records
        .where((r) => r.heightCm != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (withHeight.length < 2) return GrowthPeriodSummary.noData;

    final end = withHeight.last;
    final start = _findClosestBefore(
      withHeight,
      endDate: end.date,
      targetDate: end.date.subtract(Duration(days: daysBack)),
    );

    if (start == null ||
        start.date.year == end.date.year &&
            start.date.month == end.date.month &&
            start.date.day == end.date.day) {
      return GrowthPeriodSummary.noData;
    }

    return _computeFromPair(child: child, start: start, end: end);
  }

  /// 任意の2記録間の成長ペース（新しい日付を終了日、古い日付を開始日）。
  static GrowthPeriodSummary computeBetween({
    required ChildProfile child,
    required GrowthRecord recordA,
    required GrowthRecord recordB,
  }) {
    final older = recordA.date.isBefore(recordB.date) ? recordA : recordB;
    final newer = older == recordA ? recordB : recordA;
    return _computeFromPair(child: child, start: older, end: newer);
  }

  static GrowthPeriodSummary _computeFromPair({
    required ChildProfile child,
    required GrowthRecord start,
    required GrowthRecord end,
  }) {
    final startH = start.heightCm;
    final endH = end.heightCm;
    if (startH == null || endH == null) return GrowthPeriodSummary.noData;

    final from = _dateOnly(start.date);
    final to = _dateOnly(end.date);
    final daysBetween = to.difference(from).inDays;
    if (daysBetween <= 0) return GrowthPeriodSummary.noData;

    final delta = endH - startH;
    final cmPerYear = delta / daysBetween * _daysPerYear;

    final hRef =
        GrowthLms2000.heightRef(isBoy: child.gender == Gender.male);

    final elapsed = _formatPeriodStrict(from, to);

    return GrowthPeriodSummary(
      hasData: true,
      start: start,
      end: end,
      periodLabel: elapsed,
      dateRangeLabel:
          '${_formatDateSlash(from)} 〜 ${_formatDateSlash(to)}（${_formatPeriodDisplay(from, to)}）',
      heightDeltaCm: delta,
      cmPerYear: cmPerYear,
      sdStart: _heightSd(hRef, child.birthDate, start.date, startH),
      sdEnd: _heightSd(hRef, child.birthDate, end.date, endH),
    );
  }

  /// 直近約1年（365日前に最も近いデータ）。
  static GrowthPeriodSummary lastYear({
    required ChildProfile child,
    required List<GrowthRecord> records,
  }) =>
      compute(child: child, records: records, daysBack: 365);

  /// [endDate] より前の記録のうち、[targetDate] に最も日付が近いものを返す。
  static GrowthRecord? _findClosestBefore(
    List<GrowthRecord> records, {
    required DateTime endDate,
    required DateTime targetDate,
  }) {
    GrowthRecord? closest;
    var minDiffDays = 1 << 30;

    for (final r in records) {
      if (!r.date.isBefore(endDate)) continue;
      final diffDays = (r.date.difference(targetDate).inDays).abs();
      if (diffDays < minDiffDays) {
        minDiffDays = diffDays;
        closest = r;
      }
    }
    return closest;
  }

  static double? _heightSd(
    LmsReference ref,
    DateTime birthDate,
    DateTime date,
    double heightCm,
  ) {
    final months = date.difference(birthDate).inDays / _daysPerYear * 12;
    if (months < 0) return null;
    return ref.zScore(months, heightCm);
  }

  /// 時刻を除いた日付（年月日のみ）。
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 日付を「2025/08/15」形式で返す（月日はゼロ埋め2桁）。
  static String _formatDateSlash(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  /// 2日付間の厳密な経過期間（内部用・年0も含む）。
  static String _formatPeriodStrict(DateTime from, DateTime to) {
    final (y, m, d) = _periodParts(from, to);
    return '$y年$mヶ月$d日';
  }

  /// 表示用経過期間。0年の場合は「0年」を省略（例：10ヶ月11日 / 1年0ヶ月6日）。
  static String _formatPeriodDisplay(DateTime from, DateTime to) {
    final (y, m, d) = _periodParts(from, to);
    if (y == 0) {
      final parts = <String>[];
      if (m > 0) parts.add('$mヶ月');
      if (d > 0 || parts.isEmpty) parts.add('$d日');
      return parts.join('');
    }
    return '$y年$mヶ月$d日';
  }

  static (int y, int m, int d) _periodParts(DateTime from, DateTime to) {
    var y = to.year - from.year;
    var m = to.month - from.month;
    var d = to.day - from.day;
    if (d < 0) {
      m--;
      d += DateTime(to.year, to.month, 0).day;
    }
    if (m < 0) {
      y--;
      m += 12;
    }
    return (y, m, d);
  }
}
