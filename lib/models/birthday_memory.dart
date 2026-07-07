import 'dart:convert';
import 'dart:typed_data';

/// お誕生日の思い出（1歳ごとに写真・そのときのサイズ・メモを残せる）。
class BirthdayMemory {
  BirthdayMemory({
    required this.age,
    required this.savedAt,
    this.photoBytes,
    this.photoAlignX = 0.0,
    this.photoAlignY = 0.0,
    this.photoScale = 1.0,
    this.heightCm,
    this.weightKg,
    this.note,
  });

  /// 何歳のお誕生日か。
  final int age;

  /// 保存した日時。
  final DateTime savedAt;

  /// 記念写真（バイトデータ）。Web・ネイティブ両対応。
  final Uint8List? photoBytes;

  /// 正方形に切り取るときの表示位置（-1.0〜1.0、0 が中央）。
  /// 編集画面で写真をドラッグして調整し、一覧・お祝いでも同じ位置で表示する。
  final double photoAlignX;
  final double photoAlignY;

  /// 正方形に切り取るときの拡大率（1.0＝等倍、ピンチで最大4.0まで）。
  final double photoScale;

  /// お誕生日ごろの身長（cm・任意）。
  final double? heightCm;

  /// お誕生日ごろの体重（kg・任意）。
  final double? weightKg;

  /// ひとことメモ（任意）。
  final String? note;

  /// 一部だけ更新した新しいインスタンスを返す（null での消去は不可）。
  BirthdayMemory copyWith({
    DateTime? savedAt,
    Uint8List? photoBytes,
    double? photoAlignX,
    double? photoAlignY,
    double? photoScale,
    double? heightCm,
    double? weightKg,
    String? note,
  }) {
    return BirthdayMemory(
      age: age,
      savedAt: savedAt ?? this.savedAt,
      photoBytes: photoBytes ?? this.photoBytes,
      photoAlignX: photoAlignX ?? this.photoAlignX,
      photoAlignY: photoAlignY ?? this.photoAlignY,
      photoScale: photoScale ?? this.photoScale,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'savedAt': savedAt.toIso8601String(),
        'photoBytes': photoBytes != null ? base64Encode(photoBytes!) : null,
        'photoAlignX': photoAlignX,
        'photoAlignY': photoAlignY,
        'photoScale': photoScale,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'note': note,
      };

  factory BirthdayMemory.fromJson(Map<String, dynamic> json) {
    final photoRaw = json['photoBytes'];
    return BirthdayMemory(
      age: json['age'] as int,
      savedAt: DateTime.parse(json['savedAt'] as String),
      photoBytes: photoRaw != null ? base64Decode(photoRaw as String) : null,
      photoAlignX: (json['photoAlignX'] as num?)?.toDouble() ?? 0.0,
      photoAlignY: (json['photoAlignY'] as num?)?.toDouble() ?? 0.0,
      photoScale: (json['photoScale'] as num?)?.toDouble() ?? 1.0,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }
}
