/// 足長の実測記録（靴サイズ予測のアンカー）。
class FootMeasurement {
  const FootMeasurement({required this.date, required this.footLengthCm});

  final DateTime date;

  /// かかと〜つま先の実測足長（cm）。
  final double footLengthCm;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'footLengthCm': footLengthCm,
      };

  factory FootMeasurement.fromJson(Map<String, dynamic> json) =>
      FootMeasurement(
        date: DateTime.parse(json['date'] as String),
        footLengthCm: (json['footLengthCm'] as num).toDouble(),
      );
}

/// 靴の購入記録（購入した靴のサイズ）。
class ShoePurchase {
  const ShoePurchase({required this.date, required this.sizeCm});

  final DateTime date;

  /// 購入した靴のサイズ（cm）。
  final double sizeCm;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'sizeCm': sizeCm,
      };

  factory ShoePurchase.fromJson(Map<String, dynamic> json) => ShoePurchase(
        date: DateTime.parse(json['date'] as String),
        sizeCm: (json['sizeCm'] as num).toDouble(),
      );
}
