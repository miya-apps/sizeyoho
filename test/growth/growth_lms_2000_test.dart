import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/growth/growth_lms_2000.dart';
import 'package:grow_app/growth/lms_reference.dart';

/// JSPES 2000 LMS 基準（Isojima et al. Clin Pediatr Endocrinol 25:71-76, 2016）
/// の転記ミス・計算式の退行を検出するテスト。
///
/// - アンカー値: 論文 Table 2/3 の M（中央値）を独立に再記載して照合。
/// - ±2SD 回帰値: LMS 公式で事前計算した値を固定し、テーブル・式の変更を検出。
void main() {
  final boysH = GrowthLms2000.boysHeight;
  final girlsH = GrowthLms2000.girlsHeight;
  final boysW = GrowthLms2000.boysWeight;
  final girlsW = GrowthLms2000.girlsWeight;

  final allRefs = <String, LmsReference>{
    'boysHeight': boysH,
    'girlsHeight': girlsH,
    'boysWeight': boysW,
    'girlsWeight': girlsW,
  };

  group('論文アンカー値（中央値 M）', () {
    // (月齢, 期待値) — 論文 Table 2/3 から独立に転記。
    const boysHeightAnchors = [(0.0, 49.0), (12.0, 74.8), (72.0, 113.3), (210.0, 170.8)];
    const girlsHeightAnchors = [(0.0, 48.5), (12.0, 73.5), (72.0, 112.7), (210.0, 157.8)];
    const boysWeightAnchors = [(0.0, 3.00), (12.0, 9.38), (72.0, 19.6), (210.0, 60.9)];
    const girlsWeightAnchors = [(0.0, 2.95), (12.0, 8.72), (72.0, 19.4), (210.0, 52.3)];

    void checkAnchors(LmsReference ref, List<(double, double)> anchors) {
      for (final (months, expected) in anchors) {
        expect(
          ref.valueAtZ(months, 0),
          closeTo(expected, 0.001),
          reason: '月齢 $months の中央値',
        );
      }
    }

    test('男児身長', () => checkAnchors(boysH, boysHeightAnchors));
    test('女児身長', () => checkAnchors(girlsH, girlsHeightAnchors));
    test('男児体重', () => checkAnchors(boysW, boysWeightAnchors));
    test('女児体重', () => checkAnchors(girlsW, girlsWeightAnchors));
  });

  group('±2SD 回帰値（12ヶ月時点・LMS 公式で事前計算）', () {
    test('男児身長 12ヶ月', () {
      expect(boysH.valueAtZ(12, 2), closeTo(79.56, 0.05));
      expect(boysH.valueAtZ(12, -2), closeTo(69.73, 0.05));
    });

    test('女児身長 12ヶ月', () {
      expect(girlsH.valueAtZ(12, 2), closeTo(78.17, 0.05));
      expect(girlsH.valueAtZ(12, -2), closeTo(68.82, 0.05));
    });

    test('男児体重 12ヶ月', () {
      expect(boysW.valueAtZ(12, 2), closeTo(11.59, 0.05));
      expect(boysW.valueAtZ(12, -2), closeTo(7.61, 0.05));
    });

    test('女児体重 12ヶ月', () {
      expect(girlsW.valueAtZ(12, 2), closeTo(10.79, 0.05));
      expect(girlsW.valueAtZ(12, -2), closeTo(7.14, 0.05));
    });
  });

  group('LMS 計算の恒等性', () {
    test('全テーブル・全基準点で valueAtZ(m, 0) == M', () {
      for (final entry in allRefs.entries) {
        for (final e in entry.value.entries) {
          expect(
            entry.value.valueAtZ(e.ageMonths, 0),
            closeTo(e.m, 1e-9),
            reason: '${entry.key} 月齢 ${e.ageMonths}',
          );
        }
      }
    });

    test('全テーブル・全基準点で zScore(m, M) ≒ 0', () {
      for (final entry in allRefs.entries) {
        for (final e in entry.value.entries) {
          expect(
            entry.value.zScore(e.ageMonths, e.m),
            closeTo(0, 1e-9),
            reason: '${entry.key} 月齢 ${e.ageMonths}',
          );
        }
      }
    });

    test('zScore と valueAtZ は互いに逆関数（roundtrip）', () {
      const zValues = [-2.5, -2.0, -1.0, 0.0, 1.0, 2.0, 2.5];
      const ages = [0.0, 3.0, 7.5, 12.0, 30.0, 66.0, 120.0, 180.0, 210.0];
      for (final entry in allRefs.entries) {
        for (final months in ages) {
          for (final z in zValues) {
            final value = entry.value.valueAtZ(months, z);
            expect(
              entry.value.zScore(months, value),
              closeTo(z, 1e-6),
              reason: '${entry.key} 月齢 $months, Z=$z',
            );
          }
        }
      }
    });

    test('valueAtZ は Z について単調増加', () {
      const ages = [0.0, 6.0, 12.0, 60.0, 120.0, 210.0];
      for (final entry in allRefs.entries) {
        for (final months in ages) {
          var prev = double.negativeInfinity;
          for (var z = -3.0; z <= 3.0; z += 0.5) {
            final v = entry.value.valueAtZ(months, z);
            expect(
              v,
              greaterThan(prev),
              reason: '${entry.key} 月齢 $months, Z=$z',
            );
            prev = v;
          }
        }
      }
    });

    test('L = 0 の基準点（男児身長 17.5歳）は指数式で計算される', () {
      // L=0.000, M=170.8, S=0.0340 → X(+2SD) = M * exp(S*2)
      expect(boysH.valueAtZ(210, 2), closeTo(182.82, 0.05));
    });
  });

  group('補間・範囲外クランプ', () {
    test('基準点の中間月齢は隣接基準点の範囲内に補間される（単調3次）', () {
      // 12ヶ月 M=74.8 と 15ヶ月 M=77.8 の間。単調3次補間なので
      // 線形の中点(76.3)とは一致しないが、必ず両端の範囲内に収まる。
      final v = boysH.valueAtZ(13.5, 0);
      expect(v, greaterThan(74.8));
      expect(v, lessThan(77.8));
      expect(v, closeTo(76.3, 0.3));
    });

    test('補間は月齢について単調増加（オーバーシュートなし・男児身長 0〜24ヶ月）', () {
      var prev = 0.0;
      for (var m = 0.0; m <= 24.0; m += 0.1) {
        final v = boysH.valueAtZ(m, 0);
        expect(v, greaterThan(prev), reason: '月齢 $m');
        prev = v;
      }
    });

    test('範囲外の月齢は端点でクランプされる', () {
      expect(boysH.valueAtZ(-5, 0), closeTo(49.0, 0.001));
      expect(boysH.valueAtZ(300, 0), closeTo(170.8, 0.001));
    });
  });

  group('テーブルの健全性', () {
    test('全テーブルが月齢昇順・0〜210ヶ月をカバー', () {
      for (final entry in allRefs.entries) {
        final list = entry.value.entries;
        expect(list.first.ageMonths, 0, reason: entry.key);
        expect(list.last.ageMonths, 210, reason: entry.key);
        for (var i = 1; i < list.length; i++) {
          expect(
            list[i].ageMonths,
            greaterThan(list[i - 1].ageMonths),
            reason: '${entry.key} index $i',
          );
        }
      }
    });

    test('S（変動係数）は全基準点で正', () {
      for (final entry in allRefs.entries) {
        for (final e in entry.value.entries) {
          expect(e.s, greaterThan(0), reason: '${entry.key} 月齢 ${e.ageMonths}');
        }
      }
    });

    test('中央値 M は月齢とともに単調増加（身長）', () {
      for (final ref in [boysH, girlsH]) {
        for (var i = 1; i < ref.entries.length; i++) {
          expect(
            ref.entries[i].m,
            greaterThanOrEqualTo(ref.entries[i - 1].m),
            reason: '月齢 ${ref.entries[i].ageMonths}',
          );
        }
      }
    });
  });
}
