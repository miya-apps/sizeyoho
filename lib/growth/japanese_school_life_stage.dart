import 'body_index_stage.dart';
import 'growth_life_stage.dart';

/// 日本の学年（4月2日生まれ〜翌年4月1日生まれを同級生とする年度ベース）
class JapaneseSchoolLifeStage {
  JapaneseSchoolLifeStage(this.birthDate);

  final DateTime birthDate;

  late final DateTime _birth = _normalize(birthDate);

  late final int _kindergartenYear = _firstEnrollmentYear(3);
  late final int _elementaryYear = _firstEnrollmentYear(6);

  /// 乳幼児期の最終日（3歳になる年度の3月31日）
  late final DateTime infantEnd = DateTime(_kindergartenYear, 3, 31);

  /// 未就学（年少相当）開始
  late final DateTime preschoolStart = DateTime(_kindergartenYear, 4, 1);

  /// 未就学（年長相当）終了
  late final DateTime preschoolEnd = DateTime(_kindergartenYear + 3, 3, 31);

  /// 小学校開始（小1）
  late final DateTime elementaryStart = DateTime(_elementaryYear, 4, 1);

  /// 小学校終了（小6）
  late final DateTime elementaryEnd = DateTime(_elementaryYear + 6, 3, 31);

  /// 中学校開始（中1）
  late final DateTime juniorHighStart = DateTime(_elementaryYear + 6, 4, 1);

  /// 中学校終了（中3）
  late final DateTime juniorHighEnd = DateTime(_elementaryYear + 9, 3, 31);

  /// 高校開始（高1）
  late final DateTime highSchoolStart = DateTime(_elementaryYear + 9, 4, 1);

  // 旧 API 互換（体格指数の学年境界）
  DateTime get elementaryEnrollmentStart => elementaryStart;
  DateTime get kaupEndDate => infantEnd;
  DateTime get obesityStartDate => elementaryStart;
  DateTime get obesityEndDate => juniorHighEnd;
  DateTime get bmiStartDate => highSchoolStart;

  int _firstEnrollmentYear(int targetAgeOnApril1) {
    for (int y = birthDate.year; y <= birthDate.year + 25; y++) {
      if (_ageOnApril1(y) >= targetAgeOnApril1) return y;
    }
    return birthDate.year + targetAgeOnApril1;
  }

  /// 4月1日時点の満年齢（4月2日以降生まれは同年度で1歳若い）
  int _ageOnApril1(int year) {
    var age = year - birthDate.year;
    if (birthDate.month > 4 ||
        (birthDate.month == 4 && birthDate.day > 1)) {
      age--;
    }
    return age;
  }

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  ({DateTime start, DateTime end}) bounds(GrowthLifeStage stage) {
    switch (stage) {
      case GrowthLifeStage.overall:
        return (start: _birth, end: DateTime(2100, 3, 31));
      case GrowthLifeStage.infant:
        return (start: _birth, end: infantEnd);
      case GrowthLifeStage.preschool:
        return (start: preschoolStart, end: preschoolEnd);
      case GrowthLifeStage.elementary:
        return (start: elementaryStart, end: elementaryEnd);
      case GrowthLifeStage.juniorHigh:
        return (start: juniorHighStart, end: juniorHighEnd);
      case GrowthLifeStage.highSchoolPlus:
        return (start: highSchoolStart, end: DateTime(2100, 3, 31));
    }
  }

  GrowthLifeStage stageFor(DateTime measurementDate) {
    final d = _normalize(measurementDate);
    if (!d.isAfter(infantEnd)) return GrowthLifeStage.infant;
    if (!d.isAfter(preschoolEnd)) return GrowthLifeStage.preschool;
    if (!d.isAfter(elementaryEnd)) return GrowthLifeStage.elementary;
    if (!d.isAfter(juniorHighEnd)) return GrowthLifeStage.juniorHigh;
    return GrowthLifeStage.highSchoolPlus;
  }

  GrowthLifeStage currentStage() => stageFor(DateTime.now());

  bool contains(DateTime date, GrowthLifeStage stage) {
    if (stage == GrowthLifeStage.overall) {
      return ageYearsAt(date) >= 0 && ageYearsAt(date) <= 18;
    }
    final d = _normalize(date);
    final b = bounds(stage);
    return !d.isBefore(b.start) && !d.isAfter(b.end);
  }

  BodyIndexStage bodyIndexFor(GrowthLifeStage stage) {
    if (stage.isOverall) {
      return BodyIndexStage.kaup;
    }
    if (stage.usesKaupIndex) return BodyIndexStage.kaup;
    if (stage.usesObesityDegree) return BodyIndexStage.obesity;
    return BodyIndexStage.bmi;
  }

  BodyIndexStage stageForBodyIndex(DateTime measurementDate) =>
      bodyIndexFor(stageFor(measurementDate));

  double ageYearsAt(DateTime date) =>
      date.difference(birthDate).inDays / 365.25;

  double startAge(GrowthLifeStage stage) => ageYearsAt(bounds(stage).start);

  double endAge(GrowthLifeStage stage) => ageYearsAt(bounds(stage).end);
}
