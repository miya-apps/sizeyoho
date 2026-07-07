import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/export/size_guide_export_card.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';
import 'package:grow_app/models/shoe_records.dart';

void main() {
  ChildProfile childWithData() => ChildProfile(
        id: 'c1',
        name: 'テスト',
        birthDate: DateTime(2022, 8, 15),
        gender: Gender.male,
        iconIndex: 0,
        themeColor: const Color(0xFF7FA6D6),
        growthRecords: [
          GrowthRecord(
            id: 'r1',
            date: DateTime(2025, 8, 15),
            heightCm: 88.2,
            weightKg: 12.1,
          ),
          GrowthRecord(
            id: 'r2',
            date: DateTime(2026, 3, 1),
            heightCm: 91.0,
            weightKg: 12.8,
          ),
        ],
        footMeasurements: [
          FootMeasurement(date: DateTime(2026, 5, 1), footLengthCm: 14.2),
        ],
        shoePurchases: [
          ShoePurchase(date: DateTime(2026, 5, 3), sizeCm: 15.0),
        ],
      );

  testWidgets('サイズガイド書き出しカードがオーバーフローなく描画される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: SizeGuideExportCard(child: childWithData()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 洋服4季節の行と靴の要約が含まれる。
    expect(find.text('春服'), findsOneWidget);
    expect(find.text('夏服'), findsOneWidget);
    expect(find.text('秋服'), findsOneWidget);
    expect(find.text('冬服'), findsOneWidget);
    expect(find.text('いまの目安'), findsOneWidget);
    // オーバーフローがあれば pump 中に FlutterError で失敗する。
    expect(tester.takeException(), isNull);
  });

  testWidgets('記録がない子でも書き出しカードが描画される', (tester) async {
    final child = ChildProfile(
      id: 'c2',
      name: 'なし',
      birthDate: DateTime(2025, 12, 1),
      gender: Gender.female,
      iconIndex: 1,
      themeColor: const Color(0xFFDDA0AA),
      growthRecords: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(child: SizeGuideExportCard(child: child)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('足長の記録がまだありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
