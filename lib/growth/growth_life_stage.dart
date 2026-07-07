/// ライフステージ（学年・年度ベースの6区分）
enum GrowthLifeStage {
  overall,
  infant,
  preschool,
  elementary,
  juniorHigh,
  highSchoolPlus,
}

extension GrowthLifeStageX on GrowthLifeStage {
  String get label => switch (this) {
        GrowthLifeStage.overall => '全体（0〜18歳）',
        GrowthLifeStage.infant => '乳幼児（〜3歳）',
        GrowthLifeStage.preschool => '未就学（4〜6歳）',
        GrowthLifeStage.elementary => '小学生',
        GrowthLifeStage.juniorHigh => '中学生',
        GrowthLifeStage.highSchoolPlus => '高校生〜',
      };

  /// 2段目タブ用の短縮ラベル（年齢表記なし）
  String get shortLabel => switch (this) {
        GrowthLifeStage.overall => '全体（0〜18歳）',
        GrowthLifeStage.infant => '乳幼児',
        GrowthLifeStage.preschool => '未就学',
        GrowthLifeStage.elementary => '小学生',
        GrowthLifeStage.juniorHigh => '中学生',
        GrowthLifeStage.highSchoolPlus => '高校生〜',
      };

  static const List<GrowthLifeStage> zoomStages = [
    GrowthLifeStage.infant,
    GrowthLifeStage.preschool,
    GrowthLifeStage.elementary,
    GrowthLifeStage.juniorHigh,
    GrowthLifeStage.highSchoolPlus,
  ];

  bool get isOverall => this == GrowthLifeStage.overall;

  bool get usesKaupIndex =>
      this == GrowthLifeStage.infant || this == GrowthLifeStage.preschool;

  bool get usesObesityDegree =>
      this == GrowthLifeStage.elementary || this == GrowthLifeStage.juniorHigh;

  bool get usesBmi => this == GrowthLifeStage.highSchoolPlus;
}
