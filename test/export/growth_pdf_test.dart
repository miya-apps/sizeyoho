import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/export/growth_pdf.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';

void main() {
  // rootBundle からフォントアセットを読むため binding を初期化する。
  TestWidgetsFlutterBinding.ensureInitialized();

  ChildProfile makeChild({
    bool corrected = false,
    List<GrowthRecord>? records,
  }) =>
      ChildProfile(
        id: 'test',
        name: 'テスト',
        birthDate: DateTime(2024, 1, 15),
        gender: Gender.male,
        fatherHeightCm: 172,
        motherHeightCm: 158,
        useCorrectedAge: corrected,
        expectedBirthDate: corrected ? DateTime(2024, 3, 10) : null,
        growthRecords: records ??
            [
              GrowthRecord(
                id: 'r1',
                date: DateTime(2024, 4, 15),
                heightCm: 60.1,
                weightKg: 5.9,
              ),
              GrowthRecord(
                id: 'r2',
                date: DateTime(2024, 10, 15),
                heightCm: 70.3,
                weightKg: 8.4,
              ),
              // 片方のみ測定（null 許容）のレコード
              GrowthRecord(id: 'r3', date: DateTime(2025, 4, 15), heightCm: 78.0),
            ],
      );

  bool isPdf(List<int> bytes) =>
      String.fromCharCodes(bytes.take(5)) == '%PDF-';

  test('通常の子で PDF が生成される', () async {
    final bytes = await GrowthPdf.build(child: makeChild());
    expect(bytes.length, greaterThan(10000));
    expect(isPdf(bytes), isTrue);
  });

  test('修正月齢設定の子でも生成される（修正月齢列・注記あり）', () async {
    final bytes = await GrowthPdf.build(child: makeChild(corrected: true));
    expect(isPdf(bytes), isTrue);
  });

  test('記録ゼロ件でも生成される（基準曲線のみ）', () async {
    final bytes = await GrowthPdf.build(child: makeChild(records: []));
    expect(isPdf(bytes), isTrue);
  });

  test('記録が多くても（一覧表が2段組みフルでも）A4 1ページに収まる', () async {
    // ページオブジェクト（/Type /Page）の数＝ページ数。
    int countPages(List<int> bytes) => RegExp(r'/Type\s*/Page(?![a-zA-Z])')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;

    final birth = DateTime(2024, 5, 10);
    final many = [
      for (var m = 0; m < 27; m++)
        GrowthRecord(
          id: 'r$m',
          date: DateTime(birth.year, birth.month + m, birth.day),
          heightCm: 50 + m * 1.5,
          weightKg: 3.2 + m * 0.35,
        ),
    ];
    final child = ChildProfile(
      id: 'many',
      name: 'みらい',
      birthDate: birth,
      gender: Gender.male,
      fatherHeightCm: 172,
      motherHeightCm: 158,
      growthRecords: many,
    );
    final bytes = await GrowthPdf.build(child: child);
    expect(isPdf(bytes), isTrue);
    expect(countPages(bytes), 1, reason: '受診レポートは必ずA4 1枚に収める設計');
  });
}
