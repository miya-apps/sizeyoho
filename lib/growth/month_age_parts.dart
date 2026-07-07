/// 月齢と当月内経過日数（生年月日からの月齢計算結果）
class MonthAgeParts {
  const MonthAgeParts({
    required this.months,
    required this.elapsedDays,
    required this.daysInMonth,
  });

  /// 満月齢（整数）
  final int months;

  /// 当月の経過日数（前回の月齢到達日からの日数）
  final int elapsedDays;

  /// 当月の日数（当月齢到達日〜翌月齢到達日までの日数）
  final int daysInMonth;
}
