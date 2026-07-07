enum GrowthChartKind {
  /// 母子手帳スタイルの身長・体重複合グラフ
  heightWeight,

  /// 身長と SD スコアの複合グラフ
  heightSd,

  /// カウプ指数・肥満度・BMI
  bodyIndex,
}

extension GrowthChartKindX on GrowthChartKind {
  String get label => switch (this) {
        GrowthChartKind.heightWeight => '身長・体重',
        GrowthChartKind.heightSd => '身長・SD',
        GrowthChartKind.bodyIndex => '体格指数',
      };
}
