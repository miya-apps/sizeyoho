import '../models/child_profile.dart';
import '../models/growth_record.dart';
import '../models/gender.dart';
import '../models/shoe_records.dart';
import 'growth_lms_2000.dart';
import 'lms_reference.dart';

/// ベースライン SD 算出に用いる過去期間（日）。
const baselineSdLookbackDays = 180;

/// ベースライン SD 算出に用いる最大件数。
const baselineSdMaxSamples = 3;

/// 身長から JIS 準拠のジャストサイズを求める（新生児 50cm 〜）。
int justSizeForHeight(double heightCm) {
  if (heightCm < 55) return 50;
  if (heightCm < 65) return 60;
  if (heightCm < 75) return 70;
  if (heightCm < 85) return 80;
  if (heightCm < 95) return 90;
  if (heightCm < 105) return 100;
  if (heightCm < 115) return 110;
  if (heightCm < 125) return 120;
  if (heightCm < 135) return 130;
  if (heightCm < 145) return 140;
  if (heightCm < 155) return 150;
  return 160;
}

/// 季節ごとのターゲット月（今年＝シーズン終わり / 来年＝シーズンピーク）。
class ClothingSeasonDefinition {
  const ClothingSeasonDefinition({
    required this.label,
    required this.thisYearTargetMonth,
    required this.nextYearTargetMonth,
  });

  final String label;
  final int thisYearTargetMonth;
  final int nextYearTargetMonth;
}

const clothingSeasonDefinitions = [
  ClothingSeasonDefinition(
    label: '春服',
    thisYearTargetMonth: 5,
    nextYearTargetMonth: 4,
  ),
  ClothingSeasonDefinition(
    label: '夏服',
    thisYearTargetMonth: 8,
    nextYearTargetMonth: 7,
  ),
  ClothingSeasonDefinition(
    label: '秋服',
    thisYearTargetMonth: 11,
    nextYearTargetMonth: 10,
  ),
  ClothingSeasonDefinition(
    label: '冬服',
    thisYearTargetMonth: 2,
    nextYearTargetMonth: 1,
  ),
];

/// [fromMonth] から [toMonth] までの月数差（同一月なら 0）。
int monthsUntilTargetMonth(int fromMonth, int toMonth) {
  if (toMonth >= fromMonth) return toMonth - fromMonth;
  return (12 - fromMonth) + toMonth;
}

/// 現在月から見て、直近の「今年ターゲット」を先頭に4季節を並べる。
List<ClothingSeasonDefinition> rotatedSeasonsForMonth(int currentMonth) {
  final sorted = List<ClothingSeasonDefinition>.from(clothingSeasonDefinitions)
    ..sort(
      (a, b) => monthsUntilTargetMonth(
        currentMonth,
        a.thisYearTargetMonth,
      ).compareTo(
        monthsUntilTargetMonth(currentMonth, b.thisYearTargetMonth),
      ),
    );
  return sorted;
}

/// 洋服ガイドの月齢計算基準日（[ChildProfile] の修正月齢設定に準拠）。
DateTime clothingGuideAgeBaseDate(ChildProfile child) {
  if (child.useCorrectedAge && child.expectedBirthDate != null) {
    return child.expectedBirthDate!;
  }
  return child.birthDate;
}

/// 指定日時点の月齢（経過日数 / 365.25 × 12）。
double ageInMonthsAt(ChildProfile child, DateTime asOf) {
  final base = clothingGuideAgeBaseDate(child);
  final baseDay = DateTime(base.year, base.month, base.day);
  final asOfDay = DateTime(asOf.year, asOf.month, asOf.day);
  final days = asOfDay.difference(baseDay).inDays;
  if (days < 0) return 0;
  return days / 365.25 * 12;
}

LmsReference heightReferenceFor(Gender gender) =>
    GrowthLms2000.heightRef(isBoy: gender == Gender.male);

/// 画面上部サマリー用：現在身長とベースライン SD。
class ClothingGuideBaseMetrics {
  const ClothingGuideBaseMetrics({
    required this.currentHeightCm,
    required this.baselineSdScore,
    required this.currentAgeMonths,
  });

  final double currentHeightCm;
  final double baselineSdScore;
  final double currentAgeMonths;
}

/// 洋服ガイドの1シーズン分。
class ClothingTimelineEntry {
  const ClothingTimelineEntry({
    required this.title,
    required this.targetDateThisYear,
    required this.targetDateNextYear,
    required this.thisYearEstimatedHeightCm,
    required this.thisYearJustSize,
    required this.nextYearEstimatedHeightCm,
    required this.nextYearJustSize,
  });

  final String title;
  final DateTime targetDateThisYear;
  final DateTime targetDateNextYear;
  final double thisYearEstimatedHeightCm;
  final int thisYearJustSize;
  final double nextYearEstimatedHeightCm;
  final int nextYearJustSize;
}

/// ターゲット年月を、春（4月）始まりの「年度」基準の年（yyyy）で表示する。
/// 1〜3月のターゲットはカレンダー年から1引いた年を返す（例: 2027年2月 → 2026）。
String formatClothingTargetYearLabel(DateTime date) {
  final year = date.year;
  if (date.month <= 3) return '${year - 1}';
  return '$year';
}

/// 現在日から [monthOffset] ヶ月後の年月（1日固定）を返す。
DateTime clothingTargetDateFromMonthOffset(DateTime from, int monthOffset) {
  final totalMonths = from.year * 12 + (from.month - 1) + monthOffset;
  return DateTime(totalMonths ~/ 12, totalMonths % 12 + 1);
}

/// 洋服ガイド全体の計算結果。
class ClothingGuideResult {
  const ClothingGuideResult({
    required this.hasData,
    this.currentHeightCm,
    this.baselineSdScore,
    this.timeline = const [],
    this.message,
  });

  final bool hasData;
  final double? currentHeightCm;
  final double? baselineSdScore;
  final List<ClothingTimelineEntry> timeline;
  final String? message;

  static const insufficientData = ClothingGuideResult(
    hasData: false,
    message: '予測に必要なデータが足りません。身長の記録を1回以上登録してください。',
  );
}

/// ベースライン SD スコアの表示用文字列（小数第2位、符号付き）。
String formatBaselineSdScore(double sd) {
  final s = sd.toStringAsFixed(2);
  final signed = sd >= 0 ? '+$s' : s;
  return '$signed SD (直近平均)';
}

/// 身長記録（身長データあり）の件数。
int countHeightRecords(List<GrowthRecord> records) =>
    records.where((r) => r.heightCm != null).length;

/// 身長記録のうち最新のものを返す。
GrowthRecord? latestHeightRecord(List<GrowthRecord> records) {
  GrowthRecord? latest;
  for (final r in records) {
    if (r.heightCm == null) continue;
    if (latest == null || r.date.isAfter(latest.date)) {
      latest = r;
    }
  }
  return latest;
}

/// 最新測定日から過去 [baselineSdLookbackDays] 日以内の身長記録を最大 [baselineSdMaxSamples] 件。
List<GrowthRecord> recentHeightSamplesForBaseline(List<GrowthRecord> records) {
  final withHeight = records.where((r) => r.heightCm != null).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (withHeight.isEmpty) return [];

  final latest = withHeight.first;
  final cutoff = latest.date.subtract(
    const Duration(days: baselineSdLookbackDays),
  );

  return withHeight
      .where((r) => !r.date.isBefore(cutoff))
      .take(baselineSdMaxSamples)
      .toList();
}

/// 直近サンプルからベースライン SD スコア（Z 値の平均）を算出する。
double computeBaselineSdScore({
  required ChildProfile child,
  required LmsReference heightRef,
  required List<GrowthRecord> samples,
}) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final r in samples) {
    final months = ageInMonthsAt(child, r.date);
    sum += heightRef.zScore(months, r.heightCm!);
  }
  return sum / samples.length;
}

/// 履歴からサマリー用の値（現在身長・ベースライン SD・現在月齢）を取得する。
ClothingGuideBaseMetrics? loadBaseMetrics(
  ChildProfile child, {
  DateTime? asOf,
}) {
  final samples = recentHeightSamplesForBaseline(child.growthRecords);
  if (samples.isEmpty) return null;

  final latest = samples.first;
  final heightRef = heightReferenceFor(child.gender);
  final baselineSd = computeBaselineSdScore(
    child: child,
    heightRef: heightRef,
    samples: samples,
  );

  return ClothingGuideBaseMetrics(
    currentHeightCm: latest.heightCm!,
    baselineSdScore: baselineSd,
    currentAgeMonths: ageInMonthsAt(child, asOf ?? DateTime.now()),
  );
}

/// ベースライン SD と現在月齢から4シーズンのタイムラインを生成する。
List<ClothingTimelineEntry> buildClothingTimeline({
  required LmsReference heightRef,
  required double currentAgeMonths,
  required double baselineSdScore,
  int? currentMonth,
  DateTime? asOf,
}) {
  final reference = asOf ?? DateTime.now();
  final month = currentMonth ?? reference.month;
  final seasons = rotatedSeasonsForMonth(month);

  return [
    for (final season in seasons)
      _entryForSeason(
        season: season,
        heightRef: heightRef,
        currentAgeMonths: currentAgeMonths,
        baselineSdScore: baselineSdScore,
        currentMonth: month,
        referenceDate: reference,
      ),
  ];
}

ClothingTimelineEntry _entryForSeason({
  required ClothingSeasonDefinition season,
  required LmsReference heightRef,
  required double currentAgeMonths,
  required double baselineSdScore,
  required int currentMonth,
  required DateTime referenceDate,
}) {
  final monthsToThisYear = monthsUntilTargetMonth(
    currentMonth,
    season.thisYearTargetMonth,
  );
  final monthsToNextYear = monthsToThisYear + 11;

  final targetDateThisYear =
      clothingTargetDateFromMonthOffset(referenceDate, monthsToThisYear);
  final targetDateNextYear =
      clothingTargetDateFromMonthOffset(referenceDate, monthsToNextYear);

  final thisYearHeight = heightRef.valueAtZ(
    currentAgeMonths + monthsToThisYear,
    baselineSdScore,
  );
  final nextYearHeight = heightRef.valueAtZ(
    currentAgeMonths + monthsToNextYear,
    baselineSdScore,
  );

  return ClothingTimelineEntry(
    title: season.label,
    targetDateThisYear: targetDateThisYear,
    targetDateNextYear: targetDateNextYear,
    thisYearEstimatedHeightCm: thisYearHeight,
    thisYearJustSize: justSizeForHeight(thisYearHeight),
    nextYearEstimatedHeightCm: nextYearHeight,
    nextYearJustSize: justSizeForHeight(nextYearHeight),
  );
}

// ── 靴サイズ予測 ──────────────────────────────────────────────────────────

/// 次にワンサイズ上がる（＝買い替えおすすめ）タイミング1件分。
class ShoePurchaseEntry {
  const ShoePurchaseEntry({
    required this.shoeSizeCm,
    required this.approxDate,
  });

  /// 買い替え先の靴サイズ（cm）。
  final double shoeSizeCm;

  /// そのサイズに上がる予測時期（月単位の精度・1日固定）。
  final DateTime approxDate;
}

/// 靴サイズ予測の計算結果（いまの目安＋今後の買い替えタイミング）。
class ShoeSizePurchasePlan {
  const ShoeSizePurchasePlan({
    required this.measuredFootLengthCm,
    required this.measuredAt,
    required this.currentFootLengthCm,
    required this.currentShoeSizeCm,
    required this.upcoming,
    this.lastPurchase,
    this.nextPurchase,
    this.currentShoeOutgrown = false,
  });

  final double measuredFootLengthCm;
  final DateTime measuredAt;

  /// 現時点の予測足長（cm）。
  final double currentFootLengthCm;

  /// 現時点の靴サイズの目安（cm）。
  final double currentShoeSizeCm;

  /// サイズがワンサイズ上がるタイミング（直近から最大2件）。
  final List<ShoePurchaseEntry> upcoming;

  /// 最新の購入記録（あれば）。
  final ShoePurchase? lastPurchase;

  /// 次の購入の目安。購入記録があれば「今の靴がきつくなる時期」、
  /// 無ければ「次にワンサイズ上がる時期」。当面不要なら null。
  final ShoePurchaseEntry? nextPurchase;

  /// 購入記録があり、予測上すでに今の靴が小さい可能性が高い場合 true。
  final bool currentShoeOutgrown;
}

/// つま先の余裕（cm）。実測足長にこの分を足してから靴サイズに丸める。
const shoeToeAllowanceCm = 0.7;

/// 買い替えタイミングを先読みする最大月数。
const shoeForecastMaxMonths = 24;

/// 実測の鮮度警告を出す経過日数（約3ヶ月）。
const shoeMeasurementStaleDays = 90;

/// 足長（cm）から靴サイズの目安（0.5cm 刻み・切り上げ）を求める。
double shoeSizeForFootLength(double footLengthCm) =>
    ((footLengthCm + shoeToeAllowanceCm) * 2).ceil() / 2;

/// 実測足長をアンカーにした靴サイズ予測。
///
/// 実測時点の推定身長（ベースライン SD で LMS 曲線上の値）に対する
/// 足長の比率を「この子の足の大きさの個性」として固定し、
/// 将来の予測身長に同じ比率を掛けて足長を予測する。
/// そのうえで「靴サイズがワンサイズ上がる月」を探し、
/// 買い替えおすすめ時期として返す。実測が無い場合は null。
ShoeSizePurchasePlan? computeShoeSizePurchasePlan(
  ChildProfile child, {
  DateTime? asOf,
}) {
  final measurement = latestFootMeasurement(child);
  if (measurement == null) return null;

  final base = loadBaseMetrics(child, asOf: asOf);
  if (base == null) return null;

  final heightRef = heightReferenceFor(child.gender);
  final ageAtMeasure = ageInMonthsAt(child, measurement.date);
  final heightAtMeasure = heightRef.valueAtZ(
    ageAtMeasure,
    base.baselineSdScore,
  );
  if (heightAtMeasure <= 0) return null;

  final ratio = measurement.footLengthCm / heightAtMeasure;
  final reference = asOf ?? DateTime.now();

  double footAt(int monthsAhead) =>
      heightRef.valueAtZ(
        base.currentAgeMonths + monthsAhead,
        base.baselineSdScore,
      ) *
      ratio;

  final currentFoot = footAt(0);
  final currentShoe = shoeSizeForFootLength(currentFoot);
  final lastPurchase = latestShoePurchase(child);

  // 今後の買い替え候補は「すでに持っている靴のサイズ」を超えるものだけ。
  // 大きめを先買いしている場合（例：目安14.0で14.5を購入済み）に、
  // 持っているサイズと同じ候補が並ばないよう繰り上げる。
  var lastSize = currentShoe;
  if (lastPurchase != null && lastPurchase.sizeCm > lastSize) {
    lastSize = lastPurchase.sizeCm;
  }
  final upcoming = <ShoePurchaseEntry>[];
  for (var m = 1; m <= shoeForecastMaxMonths && upcoming.length < 2; m++) {
    final size = shoeSizeForFootLength(footAt(m));
    if (size > lastSize) {
      upcoming.add(
        ShoePurchaseEntry(
          shoeSizeCm: size,
          approxDate: clothingTargetDateFromMonthOffset(reference, m),
        ),
      );
      lastSize = size;
    }
  }

  // 購入記録があれば「今の靴がきつくなる時期」を次の購入目安にする。
  ShoePurchaseEntry? nextPurchase;
  var outgrown = false;
  if (lastPurchase != null && currentShoe > lastPurchase.sizeCm) {
    // 予測上、必要サイズが購入済みサイズをすでに超えている。
    outgrown = true;
    nextPurchase = ShoePurchaseEntry(
      shoeSizeCm: currentShoe,
      approxDate: DateTime(reference.year, reference.month),
    );
  } else {
    // 持っているサイズを超える最初の候補（＝upcoming の先頭）。
    nextPurchase = upcoming.isNotEmpty ? upcoming.first : null;
  }

  return ShoeSizePurchasePlan(
    measuredFootLengthCm: measurement.footLengthCm,
    measuredAt: measurement.date,
    currentFootLengthCm: currentFoot,
    currentShoeSizeCm: currentShoe,
    upcoming: upcoming,
    lastPurchase: lastPurchase,
    nextPurchase: nextPurchase,
    currentShoeOutgrown: outgrown,
  );
}

/// 最新の足長実測（無ければ null）。
FootMeasurement? latestFootMeasurement(ChildProfile child) {
  FootMeasurement? latest;
  for (final m in child.footMeasurements) {
    if (latest == null || m.date.isAfter(latest.date)) latest = m;
  }
  return latest;
}

/// 最新の靴購入記録（無ければ null）。
ShoePurchase? latestShoePurchase(ChildProfile child) {
  ShoePurchase? latest;
  for (final p in child.shoePurchases) {
    if (latest == null || p.date.isAfter(latest.date)) latest = p;
  }
  return latest;
}

/// LMS ベースライン SD から洋服サイズのタイムラインを生成する。
class ClothingSizeGuideCalculator {
  ClothingSizeGuideCalculator._();

  static ClothingGuideResult compute(ChildProfile child) {
    final base = loadBaseMetrics(child);
    if (base == null) return ClothingGuideResult.insufficientData;

    final heightRef = heightReferenceFor(child.gender);

    return ClothingGuideResult(
      hasData: true,
      currentHeightCm: base.currentHeightCm,
      baselineSdScore: base.baselineSdScore,
      timeline: buildClothingTimeline(
        heightRef: heightRef,
        currentAgeMonths: base.currentAgeMonths,
        baselineSdScore: base.baselineSdScore,
      ),
    );
  }
}
