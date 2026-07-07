import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'birthday_memory.dart';
import 'gender.dart';
import 'growth_record.dart';
import 'shoe_records.dart';

// copyWith で「変更なし」を表すセンチネル
const _kKeepPhoto = Object();
// nullable な expectedBirthDate を「未指定（維持）」と「null へクリア」で区別するためのセンチネル
const _kKeepExpected = Object();
// nullable な両親の身長を「未指定（維持）」と「null へクリア」で区別するためのセンチネル
const _kKeepParentHeight = Object();

class ChildProfile {
  ChildProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    this.iconIndex = 0,
    this.photoBytes,
    this.themeColor = const Color(0xFF2E9E8F),
    this.useCorrectedAge = false,
    this.expectedBirthDate,
    this.fatherHeightCm,
    this.motherHeightCm,
    this.birthdayCelebrationEnabled = true,
    List<int>? celebratedBirthdayAges,
    List<BirthdayMemory>? birthdayMemories,
    List<GrowthRecord>? growthRecords,
    List<FootMeasurement>? footMeasurements,
    List<ShoePurchase>? shoePurchases,
  })  : celebratedBirthdayAges = celebratedBirthdayAges ?? [],
        birthdayMemories = birthdayMemories ?? [],
        growthRecords = growthRecords ?? [],
        footMeasurements = footMeasurements ?? [],
        shoePurchases = shoePurchases ?? [];

  final String id;
  String name;
  DateTime birthDate;
  Gender gender;
  int iconIndex;

  /// 修正月齢（Corrected Age）でグラフ・月齢を扱うかどうかのフラグ。
  /// 超早産児など、出産予定日を基準に発育を評価したい場合に true にする。
  bool useCorrectedAge;

  /// 出産予定日（Null 許容）。修正月齢の計算基準となる。
  /// 未設定の場合は修正月齢を算出できないため、暦月齢のみを用いる。
  DateTime? expectedBirthDate;

  /// 父親の身長（cm・Null 許容）。PDF出力や目標身長（MPH）の参考情報。
  double? fatherHeightCm;

  /// 母親の身長（cm・Null 許容）。PDF出力や目標身長（MPH）の参考情報。
  double? motherHeightCm;

  /// 足長の実測記録（時系列）。靴サイズ予測のアンカーになる。
  List<FootMeasurement> footMeasurements;

  /// 靴の購入記録（時系列）。「今の靴がいつまで履けるか」の予測に使う。
  List<ShoePurchase> shoePurchases;

  /// お誕生日のお祝い表示を有効にするか（「今後表示しない」で false）。
  bool birthdayCelebrationEnabled;

  /// お祝いを表示済みの年齢リスト（同じ誕生日に繰り返し出さないため）。
  List<int> celebratedBirthdayAges;

  /// お誕生日の思い出写真（年齢ごとに1枚）。
  List<BirthdayMemory> birthdayMemories;

  /// 両親の身長から算出する目標身長（MPH: Mid-Parental Height, cm）。
  /// 男児: (父+母+13)/2、女児: (父+母−13)/2。どちらか未入力なら null。
  double? get midParentalHeightCm {
    final father = fatherHeightCm;
    final mother = motherHeightCm;
    if (father == null || mother == null) return null;
    return gender == Gender.male
        ? (father + mother + 13) / 2
        : (father + mother - 13) / 2;
  }

  /// 写真（バイトデータ）。Web・ネイティブ両対応。null の場合アイコン表示。
  Uint8List? photoBytes;

  /// 子供ごとのテーマカラー。ヘッダーやタブの色に反映される。
  Color themeColor;

  /// 成長記録の時系列リスト（身長・体重）。プロフィールとは独立して管理する。
  List<GrowthRecord> growthRecords;

  int get age {
    final now = DateTime.now();
    int a = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      a--;
    }
    return a < 0 ? 0 : a;
  }

  String get ageLabel => '$age歳';

  /// 指定日時点での「暦日齢」（生年月日からの経過日数）。
  /// 例：生年月日 2026/01/01・記録日 2026/05/01 → 120 日。
  int chronologicalAgeInDaysAt(DateTime asOf) =>
      _dateOnly(asOf).difference(_dateOnly(birthDate)).inDays;

  /// 指定日時点での「修正日齢」（出産予定日からの経過日数）。
  /// [expectedBirthDate] が未設定の場合は null を返す。
  /// 例：出産予定日 2026/03/01・記録日 2026/05/01 → 61 日。
  int? correctedAgeInDaysAt(DateTime asOf) {
    final expected = expectedBirthDate;
    if (expected == null) return null;
    return _dateOnly(asOf).difference(_dateOnly(expected)).inDays;
  }

  /// 設定（[useCorrectedAge]）と [expectedBirthDate] の有無に応じて、
  /// 評価に用いるべき日齢を返す。修正月齢が使えない場合は暦日齢へフォールバックする。
  int effectiveAgeInDaysAt(DateTime asOf) {
    if (useCorrectedAge) {
      final corrected = correctedAgeInDaysAt(asOf);
      if (corrected != null) return corrected;
    }
    return chronologicalAgeInDaysAt(asOf);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  IconData get iconData =>
      kChildIconOptions[iconIndex.clamp(0, kChildIconOptions.length - 1)];

  /// 表示名はユーザー入力値をそのまま使う。
  /// 敬称（くん/ちゃん）の自動付与はジェンダーバイアス排除のため行わない。
  String get displayName => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'gender': gender.name,
        'iconIndex': iconIndex,
        'photoBytes':
            photoBytes != null ? base64Encode(photoBytes!) : null,
        'themeColor': themeColor.toARGB32(),
        'useCorrectedAge': useCorrectedAge,
        'expectedBirthDate': expectedBirthDate?.toIso8601String(),
        'fatherHeightCm': fatherHeightCm,
        'motherHeightCm': motherHeightCm,
        'birthdayCelebrationEnabled': birthdayCelebrationEnabled,
        'celebratedBirthdayAges': celebratedBirthdayAges,
        'birthdayMemories': birthdayMemories.map((m) => m.toJson()).toList(),
        'footMeasurements': footMeasurements.map((m) => m.toJson()).toList(),
        'shoePurchases': shoePurchases.map((p) => p.toJson()).toList(),
        'growthRecords': growthRecords.map((r) => r.toJson()).toList(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    final photoRaw = json['photoBytes'];
    return ChildProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      gender: Gender.values.firstWhere(
        (g) => g.name == json['gender'] as String,
        // 旧データの 'unknown' は廃止。読み込めない場合は男の子を既定にする。
        orElse: () => Gender.male,
      ),
      iconIndex: json['iconIndex'] as int? ?? 0,
      photoBytes: photoRaw != null
          ? base64Decode(photoRaw as String)
          : null,
      themeColor: Color(json['themeColor'] as int),
      // 旧バージョンの保存データにキーが無くてもデフォルト値で安全に読み込む（移行不要）
      useCorrectedAge: json['useCorrectedAge'] as bool? ?? false,
      expectedBirthDate: json['expectedBirthDate'] != null
          ? DateTime.parse(json['expectedBirthDate'] as String)
          : null,
      fatherHeightCm: (json['fatherHeightCm'] as num?)?.toDouble(),
      motherHeightCm: (json['motherHeightCm'] as num?)?.toDouble(),
      birthdayCelebrationEnabled:
          json['birthdayCelebrationEnabled'] as bool? ?? true,
      celebratedBirthdayAges: (json['celebratedBirthdayAges'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      birthdayMemories: (json['birthdayMemories'] as List<dynamic>?)
              ?.map((e) => BirthdayMemory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      footMeasurements: _footMeasurementsFromJson(json),
      shoePurchases: (json['shoePurchases'] as List<dynamic>?)
              ?.map((e) => ShoePurchase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      growthRecords: (json['growthRecords'] as List<dynamic>?)
              ?.map(
                (e) => GrowthRecord.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  /// 足長実測リストの復元。旧バージョンの単一値
  /// （footLengthCm / footLengthMeasuredAt）は1件の記録として移行する。
  static List<FootMeasurement> _footMeasurementsFromJson(
    Map<String, dynamic> json,
  ) {
    final list = json['footMeasurements'] as List<dynamic>?;
    if (list != null) {
      return list
          .map((e) => FootMeasurement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final legacyFoot = (json['footLengthCm'] as num?)?.toDouble();
    if (legacyFoot == null) return [];
    final legacyDate = json['footLengthMeasuredAt'] != null
        ? DateTime.parse(json['footLengthMeasuredAt'] as String)
        : DateTime.now();
    return [FootMeasurement(date: legacyDate, footLengthCm: legacyFoot)];
  }

  ChildProfile copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    Gender? gender,
    int? iconIndex,
    // sentinel パターン: 未指定→現在値を維持、null 明示→クリア
    Object? photoBytes = _kKeepPhoto,
    Color? themeColor,
    bool? useCorrectedAge,
    Object? expectedBirthDate = _kKeepExpected,
    Object? fatherHeightCm = _kKeepParentHeight,
    Object? motherHeightCm = _kKeepParentHeight,
    bool? birthdayCelebrationEnabled,
    List<int>? celebratedBirthdayAges,
    List<BirthdayMemory>? birthdayMemories,
    List<GrowthRecord>? growthRecords,
    List<FootMeasurement>? footMeasurements,
    List<ShoePurchase>? shoePurchases,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      iconIndex: iconIndex ?? this.iconIndex,
      photoBytes: identical(photoBytes, _kKeepPhoto)
          ? this.photoBytes
          : photoBytes as Uint8List?,
      themeColor: themeColor ?? this.themeColor,
      useCorrectedAge: useCorrectedAge ?? this.useCorrectedAge,
      expectedBirthDate: identical(expectedBirthDate, _kKeepExpected)
          ? this.expectedBirthDate
          : expectedBirthDate as DateTime?,
      fatherHeightCm: identical(fatherHeightCm, _kKeepParentHeight)
          ? this.fatherHeightCm
          : fatherHeightCm as double?,
      motherHeightCm: identical(motherHeightCm, _kKeepParentHeight)
          ? this.motherHeightCm
          : motherHeightCm as double?,
      birthdayCelebrationEnabled:
          birthdayCelebrationEnabled ?? this.birthdayCelebrationEnabled,
      celebratedBirthdayAges: celebratedBirthdayAges ??
          List<int>.from(this.celebratedBirthdayAges),
      birthdayMemories:
          birthdayMemories ?? List<BirthdayMemory>.from(this.birthdayMemories),
      growthRecords:
          growthRecords ?? List<GrowthRecord>.from(this.growthRecords),
      footMeasurements: footMeasurements ??
          List<FootMeasurement>.from(this.footMeasurements),
      shoePurchases:
          shoePurchases ?? List<ShoePurchase>.from(this.shoePurchases),
    );
  }
}
