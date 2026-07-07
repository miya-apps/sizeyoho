import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';
import 'package:grow_app/widgets/growth_record_add_sheet.dart';

void main() {
  testWidgets('スマホ幅で記録シートがオーバーフローなく表示される', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final child = ChildProfile(
      id: 'c1',
      name: 'テスト',
      birthDate: DateTime(now.year - 1, now.month, 1),
      gender: Gender.male,
      growthRecords: [
        GrowthRecord(
          id: 'r1',
          date: DateTime(now.year, now.month - 1, 1),
          heightCm: 74.3,
          weightKg: 9.24,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showGrowthRecordSheet(
                  context: context,
                  child: child,
                  onSave: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 前回値（74.3cm / 9.24kg）がプリセットされている。
    expect(find.text('74.3'), findsOneWidget);
    expect(find.text('9.24'), findsOneWidget);
    // g 換算の併記。
    expect(find.textContaining('9,240'), findsOneWidget);
    // オーバーフロー等の例外が出ていないこと。
    expect(tester.takeException(), isNull);
  });
}
