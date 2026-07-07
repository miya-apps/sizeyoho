import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/growth/clothing_size_guide.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';
import 'package:grow_app/models/shoe_records.dart';

void main() {
  ChildProfile childWith({
    List<FootMeasurement>? footMeasurements,
    List<ShoePurchase>? shoePurchases,
  }) {
    final now = DateTime.now();
    return ChildProfile(
      id: 'test',
      name: 'テスト',
      birthDate: DateTime(now.year - 2, now.month, now.day),
      gender: Gender.male,
      footMeasurements: footMeasurements,
      shoePurchases: shoePurchases,
      growthRecords: [
        GrowthRecord(
          id: 'r1',
          date: now.subtract(const Duration(days: 30)),
          heightCm: 86.0,
        ),
        GrowthRecord(
          id: 'r2',
          date: now.subtract(const Duration(days: 7)),
          heightCm: 87.0,
        ),
      ],
    );
  }

  test('実測が無い場合は null', () {
    expect(computeShoeSizePurchasePlan(childWith()), isNull);
  });

  test('実測がある場合は「いまの目安」と今後の買い替え時期を返す', () {
    final now = DateTime.now();
    final child = childWith(
      footMeasurements: [
        FootMeasurement(
          date: now.subtract(const Duration(days: 7)),
          footLengthCm: 13.5,
        ),
      ],
    );
    final plan = computeShoeSizePurchasePlan(child);

    expect(plan, isNotNull);

    // 「いま」の予測足長は実測値とほぼ同じ（実測が直近のため）。
    expect(plan!.currentFootLengthCm, closeTo(13.5, 0.3));
    expect(
      plan.currentShoeSizeCm,
      shoeSizeForFootLength(plan.currentFootLengthCm),
    );

    // 2歳児は成長が速いので、24ヶ月以内に2回のサイズアップが見つかる。
    expect(plan.upcoming, hasLength(2));

    // 買い替えサイズは 0.5cm 刻みで現在サイズより大きく、単調増加。
    expect(plan.upcoming[0].shoeSizeCm, greaterThan(plan.currentShoeSizeCm));
    expect(
      plan.upcoming[1].shoeSizeCm,
      greaterThan(plan.upcoming[0].shoeSizeCm),
    );

    // 時期は未来かつ時系列順。
    expect(plan.upcoming[0].approxDate.isAfter(now), isTrue);
    expect(
      plan.upcoming[1].approxDate.isAfter(plan.upcoming[0].approxDate),
      isTrue,
    );
  });

  test('靴サイズはつま先余裕込みで 0.5cm 刻みに切り上げ', () {
    // 13.5 + 0.7 = 14.2 → 14.5
    expect(shoeSizeForFootLength(13.5), 14.5);
    // 13.8 + 0.7 = 14.5 → 14.5（ちょうど）
    expect(shoeSizeForFootLength(13.8), 14.5);
    // 14.0 + 0.7 = 14.7 → 15.0
    expect(shoeSizeForFootLength(14.0), 15.0);
  });

  test('購入記録があると「今の靴がきつくなる時期」が次の購入目安になる', () {
    final now = DateTime.now();
    final measurements = [
      FootMeasurement(
        date: now.subtract(const Duration(days: 7)),
        footLengthCm: 13.5,
      ),
    ];

    // 余裕のあるサイズ（15.5cm）を履いている → 次の購入はそれより大きいサイズで先の時期。
    final roomy = computeShoeSizePurchasePlan(
      childWith(
        footMeasurements: measurements,
        shoePurchases: [
          ShoePurchase(
            date: now.subtract(const Duration(days: 30)),
            sizeCm: 15.5,
          ),
        ],
      ),
    );
    expect(roomy, isNotNull);
    expect(roomy!.currentShoeOutgrown, isFalse);
    expect(roomy.nextPurchase, isNotNull);
    expect(roomy.nextPurchase!.shoeSizeCm, greaterThan(15.5));
    expect(roomy.nextPurchase!.approxDate.isAfter(now), isTrue);

    // 明らかに小さいサイズ（13.5cm）を履いている → すでにサイズアウト扱い。
    final tight = computeShoeSizePurchasePlan(
      childWith(
        footMeasurements: measurements,
        shoePurchases: [
          ShoePurchase(
            date: now.subtract(const Duration(days: 300)),
            sizeCm: 13.5,
          ),
        ],
      ),
    );
    expect(tight, isNotNull);
    expect(tight!.currentShoeOutgrown, isTrue);
    expect(tight.nextPurchase, isNotNull);
    expect(tight.nextPurchase!.shoeSizeCm, tight.currentShoeSizeCm);
  });

  test('大きめを先買いした場合、次以降の候補は持っているサイズより大きいものに繰り上がる', () {
    final now = DateTime.now();
    // 実測13.0 → いまの目安は 14.0（13.0+0.7=13.7 → 0.5cm刻み切り上げ）。
    // それより大きい 14.5 を先買いしている状況。
    final plan = computeShoeSizePurchasePlan(
      childWith(
        footMeasurements: [
          FootMeasurement(
            date: now.subtract(const Duration(days: 7)),
            footLengthCm: 13.0,
          ),
        ],
        shoePurchases: [
          ShoePurchase(
            date: now.subtract(const Duration(days: 3)),
            sizeCm: 14.5,
          ),
        ],
      ),
    );

    expect(plan, isNotNull);
    expect(plan!.currentShoeSizeCm, 14.0);
    expect(plan.currentShoeOutgrown, isFalse);

    // 「次」と「その先」はどちらも持っている 14.5 より大きく、単調増加。
    expect(plan.nextPurchase, isNotNull);
    expect(plan.nextPurchase!.shoeSizeCm, greaterThan(14.5));
    for (final entry in plan.upcoming) {
      expect(entry.shoeSizeCm, greaterThan(14.5));
    }
    if (plan.upcoming.length > 1) {
      expect(
        plan.upcoming[1].shoeSizeCm,
        greaterThan(plan.upcoming[0].shoeSizeCm),
      );
    }
    // 「次」は upcoming の先頭と一致する（重複表示が起きない）。
    expect(plan.nextPurchase!.shoeSizeCm, plan.upcoming.first.shoeSizeCm);
  });

  test('旧形式（単一の footLengthCm）の JSON から実測リストへ移行される', () {
    final child = childWith(
      footMeasurements: [
        FootMeasurement(date: DateTime(2026, 6, 1), footLengthCm: 13.0),
      ],
    );
    final legacyJson = child.toJson()
      ..remove('footMeasurements')
      ..remove('shoePurchases')
      ..['footLengthCm'] = 13.0
      ..['footLengthMeasuredAt'] = DateTime(2026, 6, 1).toIso8601String();

    final restored = ChildProfile.fromJson(legacyJson);
    expect(restored.footMeasurements, hasLength(1));
    expect(restored.footMeasurements.first.footLengthCm, 13.0);
    expect(restored.footMeasurements.first.date, DateTime(2026, 6, 1));
    expect(restored.shoePurchases, isEmpty);
  });
}
