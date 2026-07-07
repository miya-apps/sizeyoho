/// 成長曲線グラフの縦軸（Y軸）固定レイアウト定数。
/// ラベル配列長 = グリッド線本数。N 本の線は (N-1) 等間隔。
class GraphLayoutConstants {
  GraphLayoutConstants._();

  // 1歳：18本（17分割）
  // 身長（5〜90cm・5cm刻み）を上段、体重（0〜17kg・1kg刻み）を下段に
  // 分離するためレンジを拡張している（帯の重なり防止）。
  // 身長の上端は1目盛りぶん空けてある（+2SD曲線がグラフ上部の
  // フローティングボタンと重ならないようにするため）。
  static const int age1Divisions = 18;
  static const List<String> age1HeightLabels = [
    '',
    '85',
    '80',
    '75',
    '70',
    '65',
    '60',
    '55',
    '50',
    '45',
    '40',
    '35',
    '30',
    '',
    '',
    '',
    '',
    '',
  ];
  static const List<String> age1WeightLabels = [
    '',
    '',
    '',
    '',
    '',
    '12',
    '11',
    '10',
    '9',
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
    '1',
    '',
  ];

  // 2歳：16本（15分割）
  static const int age2Divisions = 16;
  static const List<String> age2HeightLabels = [
    '',
    '100',
    '95',
    '90',
    '85',
    '80',
    '75',
    '70',
    '65',
    '60',
    '55',
    '50',
    '45',
    '40',
    '',
    '',
  ];
  static const List<String> age2WeightLabels = [
    '',
    '',
    '',
    '',
    '',
    '20',
    '18',
    '16',
    '14',
    '12',
    '10',
    '8',
    '6',
    '4',
    '2',
    '',
  ];

  // 4歳：18本（17分割）
  static const int age4Divisions = 18;
  static const List<String> age4HeightLabels = [
    '',
    '110',
    '105',
    '100',
    '95',
    '90',
    '85',
    '80',
    '75',
    '70',
    '65',
    '60',
    '55',
    '50',
    '45',
    '40',
    '35',
    '',
  ];
  static const List<String> age4WeightLabels = [
    '',
    '',
    '',
    '',
    '',
    '24',
    '22',
    '20',
    '18',
    '16',
    '14',
    '12',
    '10',
    '8',
    '6',
    '4',
    '2',
    '',
  ];

  // 8歳：16本（15分割）
  static const int age8Divisions = 16;
  static const List<String> age8HeightLabels = [
    '',
    '140',
    '130',
    '120',
    '110',
    '100',
    '90',
    '80',
    '70',
    '60',
    '50',
    '40',
    '30',
    '',
    '',
    '',
  ];
  static const List<String> age8WeightLabels = [
    '',
    '',
    '',
    '60',
    '55',
    '50',
    '45',
    '40',
    '35',
    '30',
    '25',
    '20',
    '15',
    '10',
    '5',
    '',
  ];

  // 12歳：21本（20分割）
  // 12歳付近で身長 -2SD と体重 +2SD が接近するため、身長（-20〜180cm・
  // 10cm刻み）を上段、体重（0〜100kg・5kg刻み）を下段に分離している。
  static const int age12Divisions = 21;
  static const List<String> age12HeightLabels = [
    '',
    '170',
    '160',
    '150',
    '140',
    '130',
    '120',
    '110',
    '100',
    '90',
    '80',
    '70',
    '60',
    '50',
    '40',
    '30',
    '',
    '',
    '',
    '',
    '',
  ];
  static const List<String> age12WeightLabels = [
    '',
    '',
    '',
    '',
    '',
    '',
    '70',
    '65',
    '60',
    '55',
    '50',
    '45',
    '40',
    '35',
    '30',
    '25',
    '20',
    '15',
    '10',
    '5',
    '',
  ];

  // 18歳：19本（18分割）
  static const int age18Divisions = 19;
  static const List<String> age18HeightLabels = [
    '',
    '200',
    '190',
    '180',
    '170',
    '160',
    '150',
    '140',
    '130',
    '120',
    '110',
    '100',
    '90',
    '80',
    '70',
    '60',
    '',
    '',
    '',
  ];
  static const List<String> age18WeightLabels = [
    '',
    '',
    '',
    '',
    '',
    '',
    '120',
    '110',
    '100',
    '90',
    '80',
    '70',
    '60',
    '50',
    '40',
    '30',
    '20',
    '10',
    '',
  ];

  static int yGridLineCountForMode(int ageYears) => switch (ageYears) {
    1 => age1Divisions,
    2 => age2Divisions,
    4 => age4Divisions,
    8 => age8Divisions,
    12 => age12Divisions,
    18 => age18Divisions,
    _ => age4Divisions,
  };

  static List<String> heightLabelsForMode(int ageYears) => switch (ageYears) {
    1 => age1HeightLabels,
    2 => age2HeightLabels,
    4 => age4HeightLabels,
    8 => age8HeightLabels,
    12 => age12HeightLabels,
    18 => age18HeightLabels,
    _ => age4HeightLabels,
  };

  static List<String> weightLabelsForMode(int ageYears) => switch (ageYears) {
    1 => age1WeightLabels,
    2 => age2WeightLabels,
    4 => age4WeightLabels,
    8 => age8WeightLabels,
    12 => age12WeightLabels,
    18 => age18WeightLabels,
    _ => age4WeightLabels,
  };
}
