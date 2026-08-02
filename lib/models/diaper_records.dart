import '../growth/diaper_master.dart' show DiaperType;

/// おむつガイドの選択枠（最大3つ）。各枠が独立して
/// 「シリーズ × テープ/パンツ」を持つ（自宅＝パンツ・預け先＝テープ等の併用対応）。
///
/// [ChildProfile] に内包して子どもごとに保持する（footMeasurements と同型）。
/// 「いま使っているサイズ」は記録しない（開くたびに体重から計算する）。
class DiaperSlot {
  const DiaperSlot({
    required this.slotIndex,
    required this.seriesId,
    required this.type,
  });

  /// 枠の位置（0, 1, 2）。
  final int slotIndex;

  /// マスタデータの series_id。
  final String seriesId;

  final DiaperType type;

  Map<String, dynamic> toJson() => {
        'slotIndex': slotIndex,
        'seriesId': seriesId,
        'type': type.name,
      };

  factory DiaperSlot.fromJson(Map<String, dynamic> json) => DiaperSlot(
        slotIndex: json['slotIndex'] as int,
        seriesId: json['seriesId'] as String,
        type: DiaperType.values.firstWhere(
          (t) => t.name == json['type'] as String,
          orElse: () => DiaperType.pants,
        ),
      );
}

// 「モレの記録」は廃止した。現在サイズを記録させない設計のため
// 「どのサイズで漏れたか」が分からず、記録として成立しないため。
