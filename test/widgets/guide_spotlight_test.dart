import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/app/app_shell.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('チュートリアルの各ステップでスポットライト矩形が取得できる', (tester) async {
    await initializeDateFormatting('ja');
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    // 設定 → チュートリアルを見る で再生
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    // 設定項目が増えて画面外に出ることがあるため、スクロールして表示する。
    await tester.ensureVisible(find.text('チュートリアルを見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('チュートリアルを見る'));
    await tester.pumpAndSettle();

    expect(find.text('まずは記録してみましょう'), findsOneWidget);

    Rect? holeOf() {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      for (final cp in paints) {
        if (cp.painter.runtimeType.toString() == '_GuideSpotlightPainter') {
          // ignore: avoid_dynamic_calls
          return (cp.painter as dynamic).hole as Rect?;
        }
      }
      fail('スポットライトのスクリムが見つからない');
    }

    // 各ステップの期待値（スポットライト対象があるか）
    const expectHole = [true, false, true, true, true, true, true, true];
    for (var step = 0; step < expectHole.length; step++) {
      final hole = holeOf();
      if (expectHole[step]) {
        expect(hole, isNotNull, reason: 'step $step でスポットライトが無い');
      } else {
        expect(hole, isNull, reason: 'step $step は全面スクリムのはず');
      }
      // くり抜きが実際の対象ボタンの位置と一致しているかも検証する。
      if (step == 0) {
        final fab = tester.getRect(find.byType(FloatingActionButton));
        expect(hole!.contains(fab.center), isTrue,
            reason: '＋ボタンがスポットライトから外れている');
      }
      if (step == 6) {
        final switcher = tester.getRect(find.byType(PopupMenuButton<int>));
        expect(hole!.contains(switcher.center), isTrue,
            reason: '名前ボタンがスポットライトから外れている');
      }
      if (step < expectHole.length - 1) {
        await tester.tap(find.text('次へ'));
        await tester.pumpAndSettle();
      }
    }
  });
}
