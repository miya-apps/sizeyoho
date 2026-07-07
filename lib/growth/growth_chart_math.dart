import 'lms_reference.dart';
import 'month_age_parts.dart';

/// 成長曲線・体格指数の算出。SD スコアは LMS 法（[LmsReference]）で行う。
class GrowthChartMath {
  GrowthChartMath._();

  static DateTime _normalizeDate(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// 月の日数に合わせて日をクランプ（例：1/31生まれの2月補正）
  static DateTime _safeDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  /// 生年月日と記録日から月齢（整数）・当月経過日数・当月日数を算出
  static MonthAgeParts monthAgeParts(
    DateTime birthDate,
    DateTime measurementDate,
  ) {
    final birth = _normalizeDate(birthDate);
    final measure = _normalizeDate(measurementDate);
    if (measure.isBefore(birth)) {
      return const MonthAgeParts(months: 0, elapsedDays: 0, daysInMonth: 30);
    }

    var months =
        (measure.year - birth.year) * 12 + measure.month - birth.month;
    if (measure.day < birth.day) months--;

    final monthStartYear = birth.year + (birth.month - 1 + months) ~/ 12;
    final monthStartMonth = (birth.month - 1 + months) % 12 + 1;
    final monthStart = _safeDate(monthStartYear, monthStartMonth, birth.day);

    final nextMonthIndex = months + 1;
    final monthEndYear = birth.year + (birth.month - 1 + nextMonthIndex) ~/ 12;
    final monthEndMonth = (birth.month - 1 + nextMonthIndex) % 12 + 1;
    final monthEnd = _safeDate(monthEndYear, monthEndMonth, birth.day);

    final daysInMonth = monthEnd.difference(monthStart).inDays;
    final elapsedDays = measure.difference(monthStart).inDays;

    return MonthAgeParts(
      months: months,
      elapsedDays: elapsedDays.clamp(0, daysInMonth > 0 ? daysInMonth : 0),
      daysInMonth: daysInMonth > 0 ? daysInMonth : 30,
    );
  }

  /// 生年月日と記録日から「小数月齢」を求める（日齢を当月日数で按分）。
  static double ageInMonths(DateTime birthDate, DateTime measurementDate) {
    final parts = monthAgeParts(birthDate, measurementDate);
    final frac =
        parts.daysInMonth > 0 ? parts.elapsedDays / parts.daysInMonth : 0.0;
    return parts.months + frac;
  }

  /// LMS 基準から、指定月齢・Z スコアの計測値を逆算（基準線描画用）。
  static double valueAtZ(LmsReference ref, double ageMonths, double z) =>
      ref.valueAtZ(ageMonths, z);

  /// 実測値の SD スコア（Z 値）を LMS 法で算出。
  static double sdScore(
    LmsReference ref,
    DateTime birthDate,
    DateTime measurementDate,
    double value,
  ) =>
      ref.zScore(ageInMonths(birthDate, measurementDate), value);

  /// カウプ指数（幼稚園・保育園期）：体重(g) ÷ 身長(cm)² × 10
  static double kaupIndex(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0;
    return weightKg * 10000 / (heightCm * heightCm);
  }

  /// BMI（高校以降）
  static double bmi(double weightKg, double heightCm) {
    final hm = heightCm / 100;
    if (hm <= 0) return 0;
    return weightKg / (hm * hm);
  }

  static double sdToChartY(double sd, double minH, double maxH) {
    final clamped = sd.clamp(-3.0, 3.0);
    return minH + (clamped + 3) / 6 * (maxH - minH);
  }

  static double chartYToSd(double y, double minH, double maxH) {
    if (maxH <= minH) return 0;
    return (y - minH) / (maxH - minH) * 6 - 3;
  }
}
