import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/export/guide_export_cards.dart';
import 'package:grow_app/growth/diaper_master.dart' show DiaperType;
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/diaper_records.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';
import 'package:grow_app/models/shoe_records.dart';
import 'package:grow_app/monetization/pro_status.dart';

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

  Future<void> pumpCard(
    WidgetTester tester,
    SizeExportItem item,
    ChildProfile child, {
    bool maskName = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: GuideExportCard(item: item, child: child, maskName: maskName),
        ),
      ),
    );
  }

  testWidgets('洋服カテゴリの書き出しカードがオーバーフローなく描画される', (tester) async {
    await pumpCard(tester, SizeExportItem.clothing, childWithData());
    await tester.pumpAndSettle();

    // 洋服4季節の行が含まれる。
    expect(find.text('春服'), findsOneWidget);
    expect(find.text('夏服'), findsOneWidget);
    expect(find.text('秋服'), findsOneWidget);
    expect(find.text('冬服'), findsOneWidget);
    // SNS向けのガード文言とクレジット（©＋URL）が焼き込まれている。
    expect(find.textContaining('※あくまで目安です'), findsOneWidget);
    expect(find.textContaining('miya-apps.github.io/sizeyoho'), findsOneWidget);
    // オーバーフローがあれば pump 中に FlutterError で失敗する。
    expect(tester.takeException(), isNull);
  });

  testWidgets('名前伏せOFF：見出しに名前が入る', (tester) async {
    await pumpCard(tester, SizeExportItem.clothing, childWithData());
    await tester.pumpAndSettle();

    expect(find.text('テスト の洋服サイズ予報'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('名前伏せON：名前が消え、アイコンだけが見出しに付く', (tester) async {
    await pumpCard(
      tester,
      SizeExportItem.clothing,
      childWithData(),
      maskName: true,
    );
    await tester.pumpAndSettle();

    // 名前はどこにも出ない。見出しは種別名のみ＋アイコン。
    expect(find.textContaining('テスト'), findsNothing);
    expect(find.text('洋服サイズ予報'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('靴カテゴリの書き出しカードがオーバーフローなく描画される', (tester) async {
    await pumpCard(tester, SizeExportItem.shoe, childWithData());
    await tester.pumpAndSettle();

    expect(find.text('いまの目安'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('記録がない子でも靴カードが描画される', (tester) async {
    final child = ChildProfile(
      id: 'c2',
      name: 'なし',
      birthDate: DateTime(2025, 12, 1),
      gender: Gender.female,
      iconIndex: 1,
      themeColor: const Color(0xFFDDA0AA),
      growthRecords: const [],
    );
    await pumpCard(tester, SizeExportItem.shoe, child);
    await tester.pumpAndSettle();
    expect(find.text('足長の記録がまだありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro版の靴カードには「いま→次の購入→その先」のステップが出る', (tester) async {
    ProStatus.isPro.value = true;
    addTearDown(() => ProStatus.isPro.value = false);

    await pumpCard(tester, SizeExportItem.shoe, childWithData());
    await tester.pumpAndSettle();

    // 先頭行は「📍いま」バッジ＋「おすすめ」ラベル。
    expect(find.text('📍いま'), findsOneWidget);
    expect(find.text('おすすめ'), findsOneWidget);
    // 実測日からの経過で状態が変わる：通常なら「次の購入」行、
    // サイズアウトなら警告バナー＋「その先」行のどちらかになる。
    final hasNextRow = find.text('次の購入').evaluate().isNotEmpty;
    final hasOutgrownBanner =
        find.textContaining('小さくなっている可能性').evaluate().isNotEmpty;
    expect(hasNextRow || hasOutgrownBanner, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('おむつ3枠でもコンパクトカードでオーバーフローなく描画される', (tester) async {
    final child = ChildProfile(
      id: 'c5',
      name: 'おむつ3枠',
      birthDate: DateTime(2025, 6, 1),
      gender: Gender.male,
      iconIndex: 0,
      themeColor: const Color(0xFF7FA6D6),
      diaperGuideEnabled: true,
      growthRecords: [
        GrowthRecord(id: 'r1', date: DateTime(2026, 6, 1), weightKg: 9.0),
      ],
      diaperSlots: const [
        DiaperSlot(slotIndex: 0, seriesId: 'moony_natural', type: DiaperType.tape),
        DiaperSlot(slotIndex: 1, seriesId: 'pampers_hadaichi', type: DiaperType.pants),
        DiaperSlot(slotIndex: 2, seriesId: 'merries_first', type: DiaperType.tape),
      ],
    );
    await pumpCard(tester, SizeExportItem.diaper, child);
    await tester.pumpAndSettle();

    expect(find.text('現在の体重'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('おむつカテゴリの書き出しカードがオーバーフローなく描画される', (tester) async {
    final child = ChildProfile(
      id: 'c3',
      name: 'おむつ子',
      birthDate: DateTime(2025, 6, 1),
      gender: Gender.female,
      iconIndex: 0,
      themeColor: const Color(0xFFDDA0AA),
      diaperGuideEnabled: true,
      growthRecords: [
        GrowthRecord(id: 'r1', date: DateTime(2026, 6, 1), weightKg: 9.0),
      ],
      diaperSlots: const [
        DiaperSlot(slotIndex: 0, seriesId: 'moony_natural', type: DiaperType.tape),
      ],
    );
    await pumpCard(tester, SizeExportItem.diaper, child);
    await tester.pumpAndSettle();

    expect(find.text('現在の体重'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('体重未記録でもおむつカードが描画される', (tester) async {
    final child = ChildProfile(
      id: 'c4',
      name: 'おむつ子2',
      birthDate: DateTime(2025, 6, 1),
      gender: Gender.male,
      iconIndex: 0,
      themeColor: const Color(0xFF7FA6D6),
      diaperGuideEnabled: true,
      growthRecords: const [],
    );
    await pumpCard(tester, SizeExportItem.diaper, child);
    await tester.pumpAndSettle();

    expect(find.text('サイズの表示には体重の記録が必要です'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('成長曲線の書き出しカードがオーバーフローなく描画される', (tester) async {
    await pumpCard(tester, SizeExportItem.growthChart, childWithData());
    await tester.pumpAndSettle();

    expect(find.textContaining('の成長曲線'), findsOneWidget);
    // 直近の記録の吹き出し（グラフ内）と基準の出典が焼き込まれる。
    expect(find.textContaining('直近の記録'), findsOneWidget);
    expect(find.textContaining('身長 '), findsOneWidget);
    expect(find.textContaining('日本小児内分泌学会'), findsOneWidget);
    expect(find.textContaining('miya-apps.github.io/sizeyoho'), findsOneWidget);
    // サイズ感のガード文言はサイズを予測するガイド専用（グラフには出さない）。
    expect(find.textContaining('※あくまで目安です'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SDスコアの書き出しカードがオーバーフローなく描画される', (tester) async {
    await pumpCard(tester, SizeExportItem.sdChart, childWithData());
    await tester.pumpAndSettle();

    expect(find.textContaining('SDスコア'), findsWidgets);
    // 凡例（身長・体重・正常範囲）が含まれる。
    expect(find.text('正常範囲(±2SD)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('記録がない子ではグラフカードに空メッセージが出る', (tester) async {
    final child = ChildProfile(
      id: 'c6',
      name: 'なし',
      birthDate: DateTime(2025, 12, 1),
      gender: Gender.female,
      iconIndex: 1,
      themeColor: const Color(0xFFDDA0AA),
      growthRecords: const [],
    );
    await pumpCard(tester, SizeExportItem.growthChart, child);
    await tester.pumpAndSettle();
    expect(find.text('身長・体重の記録がまだありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
