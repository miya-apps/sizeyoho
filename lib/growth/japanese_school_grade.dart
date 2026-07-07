/// 日本の学年（4月1日時点の年齢）に基づく学齢・学年ラベル。
class JapaneseSchoolGrade {
  JapaneseSchoolGrade._();

  /// 誕生日の所属年度（Cohort Year）。
  /// 1〜3月生まれは `birthDate.year - 1`、4月以降は `birthDate.year`。
  static int cohortYear(DateTime birthDate) =>
      birthDate.month <= 3 ? birthDate.year - 1 : birthDate.year;

  /// 記録日の所属年度（Record Nendo）。
  static int recordNendo(DateTime recordDate) =>
      recordDate.month <= 3 ? recordDate.year - 1 : recordDate.year;

  /// 指定年度（4月始まり）における学齢（4月1日時点の満年齢）。
  static int ageInFiscalYear(int fiscalYear, DateTime birthDate) =>
      fiscalYear - cohortYear(birthDate) - 1;

  /// 学齢を学年ラベルに変換する。
  static String labelForAge(int age) {
    if (age < 0) return '誕生前';
    return switch (age) {
      0 => '0歳児',
      1 => '1歳児',
      2 => '2歳児',
      3 => '年少',
      4 => '年中',
      5 => '年長',
      >= 6 && <= 11 => '小学${age - 5}年生',
      12 => '中学1年生',
      13 => '中学2年生',
      14 => '中学3年生',
      15 => '高校1年生',
      16 => '高校2年生',
      17 => '高校3年生',
      _ => '$age歳',
    };
  }

  /// 記録年度と誕生日から学年ラベルを返す。
  static String labelForFiscalYear(int fiscalYear, DateTime birthDate) =>
      labelForAge(ageInFiscalYear(fiscalYear, birthDate));
}
