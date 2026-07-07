import 'dart:math';

/// 体重（kg）の表示用フォーマット。
/// 10g 単位の端数があるときだけ小数2桁、それ以外は従来どおり小数1桁で表示する。
/// 例: 3.15 → "3.15"、3.1 → "3.1"、12.0 → "12.0"。
String formatWeightKg(double v) {
  final centi = (v * 100).round();
  return centi % 10 == 0
      ? (centi / 100).toStringAsFixed(1)
      : (centi / 100).toStringAsFixed(2);
}

/// 成長記録（身長・体重の時系列データ）。
/// プロフィールから切り離すことで将来のグラフ化に対応する。
///
/// 身長・体重は「片方のみ測定」を許容するため null 許容。
/// どちらも null のレコードは意味を持たない（入力UI側で両方OFFの保存を禁止）。
/// [id] で一意に識別し、日付変更時も同一レコードとして更新する。
class GrowthRecord {
  const GrowthRecord({
    required this.id,
    required this.date,
    this.heightCm,
    this.weightKg,
  });

  final String id;
  final DateTime date;
  final double? heightCm;
  final double? weightKg;

  /// 新規レコード用 ID を自動採番する。
  static String generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(0xFFFFFF);
    return '${ts.toRadixString(36)}_${r.toRadixString(36)}';
  }

  /// JSON から復元した既存データ向けの安定 ID（日付ベース・移行用）。
  static String legacyIdFromDate(DateTime date) =>
      'legacy_${date.toIso8601String()}';

  GrowthRecord copyWith({
    String? id,
    DateTime? date,
    double? heightCm,
    double? weightKg,
    bool clearHeight = false,
    bool clearWeight = false,
  }) =>
      GrowthRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
      };

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    return GrowthRecord(
      id: json['id'] as String? ?? legacyIdFromDate(date),
      date: date,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
    );
  }
}
