/// おむつガイドの核ロジック（はしご・ゆらぎ区間・体重の位置判定）のテスト。
///
/// - 4パターン（隙間 / 接している / 真の重複 / 内包・退化）の区間計算
/// - 体重スイープでの「クリーン ⇔ ゆらぎ」切り替わり
/// - はしご1段のみ・下回り・上回りの境界ケース
/// 実在データ（生成済みマスタ）と合成データの両方で確認する。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/growth/diaper_master.dart';
import 'package:grow_app/growth/diaper_master_data.g.dart';
import 'package:grow_app/growth/diaper_size_guide.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';

DiaperSizeBand _band(String label, double min, double max) =>
    DiaperSizeBand(sizeLabel: label, minKg: min, maxKg: max);

/// マスタから実データのはしごを取り出す。
/// group 本体（テスト外）でも呼ぶため expect は使わない
/// （存在しなければ ! で即例外になり、テストの失敗として現れる）。
List<DiaperSizeBand> _ladderOf(String seriesId, DiaperType type) =>
    findDiaperSeriesById(kDiaperBrands, seriesId)!.bandsFor(type);

void main() {
  group('ゆらぎ区間の4パターン', () {
    test('真の重複：重複区間そのものがゆらぎ区間（実データ S 4-8 / M 6-11）', () {
      // パンパース さらさらケア テープ：新生児/S/M/L
      final ladder = _ladderOf('pampers_sarasara', DiaperType.tape);
      final transitions = computeDiaperTransitions(ladder);
      expect(transitions.length, ladder.length - 1);

      final sToM = transitions[1]; // S(4-8) → M(6-11)
      expect(sToM.kind, DiaperTransitionKind.trueOverlap);
      expect(sToM.zoneMinKg, 6.0);
      expect(sToM.zoneMaxKg, 8.0);
      expect(sToM.centerKg, 7.0);
    });

    test('内包・退化：小さい方の上限±定数だけがゆらぎ区間（実データ 3S 0-3 / 新生児 0-5）', () {
      // パンパース 肌へのいちばん テープ：3S小さめ新生児/新生児/S/M/L
      final ladder = _ladderOf('pampers_hadaichi', DiaperType.tape);
      final transitions = computeDiaperTransitions(ladder);

      final threeSToNb = transitions[0]; // 3S(0-3) → 新生児(0-5)
      expect(threeSToNb.kind, DiaperTransitionKind.contained);
      expect(threeSToNb.zoneMinKg, 3.0 - kDiaperTransitionMarginKg);
      expect(threeSToNb.zoneMaxKg, 3.0 + kDiaperTransitionMarginKg);
      expect(threeSToNb.centerKg, 3.0);
    });

    test('内包ケースで真の重複の式（区間全体）にならないこと＝1.0kgはクリーン', () {
      // 真の重複の式を誤用すると区間が [0,3] になり 1.0kg が常時ゆらぎ判定になる。
      final ladder = _ladderOf('pampers_hadaichi', DiaperType.tape);
      final result = evaluateDiaperFit(ladder: ladder, weightKg: 1.0);
      expect(result.status, DiaperFitStatus.clean);
      expect(result.currentIndex, 0, reason: '体重を含む最小のサイズ＝3S小さめ新生児');
    });

    test('接している：境界点±定数（合成データ 5-8 / 8-12）', () {
      final ladder = [_band('A', 5, 8), _band('B', 8, 12)];
      final transitions = computeDiaperTransitions(ladder);
      expect(transitions.single.kind, DiaperTransitionKind.touching);
      expect(transitions.single.zoneMinKg, 8.0 - kDiaperTransitionMarginKg);
      expect(transitions.single.zoneMaxKg, 8.0 + kDiaperTransitionMarginKg);
      expect(transitions.single.centerKg, 8.0);
    });

    test('隙間がある：隙間の中点±定数（合成データ 4-6 / 7-10）', () {
      final ladder = [_band('A', 4, 6), _band('B', 7, 10)];
      final transitions = computeDiaperTransitions(ladder);
      expect(transitions.single.kind, DiaperTransitionKind.gap);
      expect(transitions.single.zoneMinKg, 6.5 - kDiaperTransitionMarginKg);
      expect(transitions.single.zoneMaxKg, 6.5 + kDiaperTransitionMarginKg);
      expect(transitions.single.centerKg, 6.5);
    });

    test('広い隙間でも、隙間の中の体重が宙に浮かず「ゆらぎの中」になる', () {
      // 隙間 [6,8] は ±0.5 の窓より広い。窓の外だがどのサイズにも
      // 属さない 6.2kg も「ゆらぎの中」として扱う（安全網）。
      final ladder = [_band('A', 4, 6), _band('B', 8, 12)];
      final result = evaluateDiaperFit(ladder: ladder, weightKg: 6.2);
      expect(result.status, DiaperFitStatus.inTransition);
      expect(result.transition!.kind, DiaperTransitionKind.gap);
    });

    test('言い切り可否：真の重複だけが言い切り可', () {
      bool assertive(List<DiaperSizeBand> ladder) =>
          computeDiaperTransitions(ladder).single.allowsAssertiveWording;

      expect(assertive([_band('A', 4, 8), _band('B', 6, 11)]), isTrue,
          reason: '真の重複＝両方の公表範囲に入っているので言い切ってよい');
      expect(assertive([_band('A', 5, 8), _band('B', 8, 12)]), isFalse,
          reason: '接している＝大きい方の下限ちょうど。控えめ表現');
      expect(assertive([_band('A', 4, 6), _band('B', 7, 10)]), isFalse,
          reason: '隙間＝どちらの公表範囲にも入らない体重を含む。控えめ表現');
      expect(assertive([_band('A', 0, 3), _band('B', 0, 5)]), isFalse,
          reason: '内包＝下限では区別できない。控えめ表現');
    });
  });

  group('体重スイープ（実データ：パンパース 肌へのいちばん テープ）', () {
    // はしご: 3S(0-3) / 新生児(0-5) / S(4-8) / M(6-11) / L(9-14)
    // ゆらぎ:  [2.5,3.5]内包 / [4,5]重複 / [6,8]重複 / [9,11]重複
    // （真の重複には接近窓を持たせない：区間に入るまではクリーン）
    final ladder = _ladderOf('pampers_hadaichi', DiaperType.tape);

    DiaperFitResult fit(double kg) =>
        evaluateDiaperFit(ladder: ladder, weightKg: kg);

    test('クリーン区間では体重を含む最小のサイズが現在地になる', () {
      expect(fit(2.0).status, DiaperFitStatus.clean);
      expect(fit(2.0).currentIndex, 0); // 3S（新生児 0-5 にも入るが小さい方）

      expect(fit(5.2).status, DiaperFitStatus.clean);
      expect(fit(5.2).currentIndex, 2); // S

      expect(fit(8.2).status, DiaperFitStatus.clean);
      expect(fit(8.2).currentIndex, 3); // M

      expect(fit(12.0).status, DiaperFitStatus.clean);
      expect(fit(12.0).currentIndex, 4); // L
    });

    test('各境界付近では対応するペアのゆらぎになる', () {
      final cases = <double, int>{
        3.0: 0, // 3S → 新生児（内包窓 2.5-3.5）
        4.5: 1, // 新生児 → S（重複 4-5）
        7.0: 2, // S → M（重複 6-8）
        10.0: 3, // M → L（重複 9-11）
      };
      cases.forEach((kg, lowerIndex) {
        final r = fit(kg);
        expect(r.status, DiaperFitStatus.inTransition, reason: '$kg kg');
        expect(r.transition!.lowerIndex, lowerIndex, reason: '$kg kg');
        expect(r.currentIndex, lowerIndex, reason: '$kg kg');
      });
    });

    test('真の重複の区間に入る手前（旧・接近窓）はクリーン（先取りしない）', () {
      // ユーザーフィードバックにより接近窓を廃止：あくまで重複区間そのものに
      // 入った時点でだけ「ゆらぎの中」と判定する。
      final cases = <double, int>{
        3.8: 1, // 新生児 → S の重複[4,5]の手前。現在地は新生児のまま。
        5.7: 2, // S → M の重複[6,8]の手前。現在地は S のまま。
        8.7: 3, // M → L の重複[9,11]の手前。現在地は M のまま。
      };
      cases.forEach((kg, currentIndex) {
        final r = fit(kg);
        expect(r.status, DiaperFitStatus.clean, reason: '$kg kg');
        expect(r.currentIndex, currentIndex, reason: '$kg kg');
      });
    });

    test('重複区間の中では言い切り可（assertiveTransition が立つ）', () {
      final inOverlap = fit(7.0); // S→M の重複 [6,8] の中
      expect(inOverlap.status, DiaperFitStatus.inTransition);
      expect(inOverlap.assertiveTransition, isTrue);
    });

    test('最大サイズのクリーンでは isMaxSize が立ち、上限超えは aboveRange', () {
      final atMax = fit(13.0);
      expect(atMax.status, DiaperFitStatus.clean);
      expect(atMax.isMaxSize, isTrue);

      // 上限ちょうどはまだ範囲内。
      expect(fit(14.0).status, DiaperFitStatus.clean);
      expect(fit(14.0).isMaxSize, isTrue);

      expect(fit(15.0).status, DiaperFitStatus.aboveRange);
      expect(fit(15.0).currentIndex, isNull);
    });

    test('最大サイズ以外のクリーンでは isMaxSize が立たない', () {
      expect(fit(5.2).status, DiaperFitStatus.clean);
      expect(fit(5.2).isMaxSize, isFalse);
    });
  });

  group('はしごの端のケース', () {
    test('はしご1段のみ：ペア0件で clean/belowRange/aboveRange が正しく出る', () {
      // グーン スーパーBIG テープはサイズが1つだけ（15-35）。
      final ladder = _ladderOf('goon_superbig', DiaperType.tape);
      expect(ladder, hasLength(1));
      expect(computeDiaperTransitions(ladder), isEmpty);

      final inside = evaluateDiaperFit(ladder: ladder, weightKg: 20.0);
      expect(inside.status, DiaperFitStatus.clean);
      expect(inside.isMaxSize, isTrue);

      expect(evaluateDiaperFit(ladder: ladder, weightKg: 10.0).status,
          DiaperFitStatus.belowRange);
      expect(evaluateDiaperFit(ladder: ladder, weightKg: 40.0).status,
          DiaperFitStatus.aboveRange);
    });

    test('パンツ専用シリーズ×小さい体重 → belowRange（エラーにしない）', () {
      // パンパース さらさらケア パンツの最小は Mはいはい（5-10）。
      final ladder = _ladderOf('pampers_sarasara', DiaperType.pants);
      final result = evaluateDiaperFit(ladder: ladder, weightKg: 4.0);
      expect(result.status, DiaperFitStatus.belowRange);
      expect(result.currentIndex, isNull);
      expect(result.transition, isNull);
    });
  });

  group('重複が広いはしご（夜用など）', () {
    test('複数のゆらぎ区間に同時に入る体重は、最も大きいペアを採用する', () {
      // ムーニーマン パンツ：…ビッグ(12-22) / ビッグより大きい(13-28) / スーパービッグ(18-35)
      final ladder = _ladderOf('moony', DiaperType.pants);
      final transitions = computeDiaperTransitions(ladder);

      // 20kg は「ビッグ→より大きい」[13,22] と「より大きい→スーパー」[18,28] の両方に入る。
      final zonesHit = transitions
          .where((t) => t.containsWeight(20.0, ladder))
          .toList();
      expect(zonesHit.length, greaterThanOrEqualTo(2),
          reason: 'このテストの前提：複数区間に同時に入る体重であること');

      final result = evaluateDiaperFit(ladder: ladder, weightKg: 20.0);
      expect(result.status, DiaperFitStatus.inTransition);
      expect(result.transition!.lowerIndex, zonesHit.last.lowerIndex,
          reason: '最も大きいサイズのペアが選ばれること');
      expect(ladder[result.transition!.lowerIndex].sizeLabel, 'ビッグより大きい');
    });
  });

  group('サイズアップ予報（体重トレンド）', () {
    /// 生後 [ageMonths] ヶ月・体重 [weightKg]（7日前に記録）の子ども。
    ChildProfile childWith({
      required int ageMonths,
      double? weightKg,
    }) {
      final now = DateTime.now();
      return ChildProfile(
        id: 'test',
        name: 'テスト',
        birthDate: DateTime(now.year, now.month - ageMonths, now.day),
        gender: Gender.male,
        growthRecords: [
          if (weightKg != null)
            GrowthRecord(
              id: 'w1',
              date: now.subtract(const Duration(days: 7)),
              weightKg: weightKg,
            ),
        ],
      );
    }

    test('体重記録が無ければ予報も枠の計算も null', () {
      final child = childWith(ageMonths: 6);
      expect(forecastWeightReach(child: child, targetKg: 10), isNull);
      expect(
        computeDiaperSlotGuide(
          child: child,
          ladder: _ladderOf('pampers_sarasara', DiaperType.tape),
        ),
        isNull,
      );
    });

    test('現在より重い目標には将来の時期、すでに超えた目標には weeksUntil=0 を返す', () {
      final child = childWith(ageMonths: 6, weightKg: 8.5);
      final now = DateTime.now();

      final ahead = forecastWeightReach(child: child, targetKg: 10.0);
      expect(ahead, isNotNull);
      expect(ahead!.weeksUntil, greaterThan(0));
      expect(ahead.approxDate.isAfter(now), isTrue);

      final reached = forecastWeightReach(child: child, targetKg: 5.0);
      expect(reached, isNotNull);
      expect(reached!.weeksUntil, 0);
    });

    test('先読み上限内に到達しない目標は null（エラーにしない）', () {
      final child = childWith(ageMonths: 6, weightKg: 8.5);
      expect(forecastWeightReach(child: child, targetKg: 60.0), isNull);
    });

    test('クリーン時：次の隣接ペアのゆらぎ区間の上端への到達時期を予報する', () {
      // 6ヶ月・8.2kg → さらさらケア テープでは M(6-11) のクリーン
      // （8.5kg 以上は M→L の接近窓に入るため、窓の外の体重を使う）。
      // 次のペア M→L のゆらぎ区間の上端（＝Mの公式上限）は 11kg。
      // ゆらぎの中に入った後の lowerSizeEndForecast と同じ目標体重にする
      // ことで、状態が変わる境目で見込みがジャンプしないようにしている。
      final child = childWith(ageMonths: 6, weightKg: 8.2);
      final guide = computeDiaperSlotGuide(
        child: child,
        ladder: _ladderOf('pampers_sarasara', DiaperType.tape),
      );

      expect(guide, isNotNull);
      expect(guide!.fit.status, DiaperFitStatus.clean);
      expect(guide.currentBand!.sizeLabel, 'M');
      expect(guide.nextBand!.sizeLabel, 'L');
      expect(guide.nextSizeForecast, isNotNull);
      expect(guide.nextSizeForecast!.weeksUntil, greaterThan(0));
      expect(guide.lowerSizeEndForecast, isNull);
    });

    test('ゆらぎの中（真の重複）：小さい方の上限への到達時期を予報する', () {
      // 6ヶ月・7.0kg → さらさらケア テープでは S(4-8)/M(6-11) のゆらぎ [6,8]。
      final child = childWith(ageMonths: 6, weightKg: 7.0);
      final guide = computeDiaperSlotGuide(
        child: child,
        ladder: _ladderOf('pampers_sarasara', DiaperType.tape),
      );

      expect(guide, isNotNull);
      expect(guide!.fit.status, DiaperFitStatus.inTransition);
      expect(guide.fit.transition!.kind, DiaperTransitionKind.trueOverlap);
      expect(guide.currentBand!.sizeLabel, 'S');
      expect(guide.nextBand!.sizeLabel, 'M');
      // 「◯月頃まで使えそう」の根拠：S の公式上限 8kg への到達時期。
      expect(guide.lowerSizeEndForecast, isNotNull);
      expect(guide.lowerSizeEndForecast!.weeksUntil, greaterThan(0));
      expect(guide.nextSizeForecast, isNull);
    });

    test('境界の手前（8.95kg・メリーズFP パンツ M6-12/L9-14）はクリーンで、'
        '予報は今のサイズ（M）の公式上限を目標にする', () {
      // 接近窓を廃止したため、L下限9kgの手前0.05kgでもクリーン。
      // 予報は L の下限ではなく M 自身の公式上限（12kg）への到達時期になる
      // （クリーン時の目標体重はゆらぎ区間の上端＝Mの上限と同じ値）。
      final child = childWith(ageMonths: 10, weightKg: 8.95);
      final guide = computeDiaperSlotGuide(
        child: child,
        ladder: _ladderOf('merries_first', DiaperType.pants),
      );

      expect(guide, isNotNull);
      expect(guide!.fit.status, DiaperFitStatus.clean);
      expect(guide.fit.isMaxSize, isFalse);
      expect(guide.currentBand!.sizeLabel, 'M');
      expect(guide.nextBand!.sizeLabel, 'L');
      expect(guide.nextSizeForecast, isNotNull);
      expect(guide.nextSizeForecast!.weeksUntil, greaterThan(0));
    });

    test('他シリーズでも境界の手前0.5kg未満はクリーンのまま（接近窓を先取りしない）', () {
      // さらさらケア テープ M(6-11)/L(9-14)：8.6kg は L 下限 9kg の手前だが、
      // 接近窓を廃止したのでクリーン（現在地は M のまま）。
      final child = childWith(ageMonths: 9, weightKg: 8.6);
      final guide = computeDiaperSlotGuide(
        child: child,
        ladder: _ladderOf('pampers_sarasara', DiaperType.tape),
      );

      expect(guide, isNotNull);
      expect(guide!.fit.status, DiaperFitStatus.clean);
      expect(guide.currentBand!.sizeLabel, 'M');
    });

    test('下回り：最小サイズの下限に到達する時期を補足として持つ', () {
      // 2ヶ月・4.5kg → さらさらケア パンツ（最小 Mはいはい 5kg〜）は対象外。
      final child = childWith(ageMonths: 2, weightKg: 4.5);
      final guide = computeDiaperSlotGuide(
        child: child,
        ladder: _ladderOf('pampers_sarasara', DiaperType.pants),
      );

      expect(guide, isNotNull);
      expect(guide!.fit.status, DiaperFitStatus.belowRange);
      expect(guide.currentBand, isNull);
      expect(guide.nextSizeForecast, isNotNull);
      expect(guide.nextSizeForecast!.weeksUntil, greaterThan(0));
    });

    test(
      '最大サイズのクリーンでは次サイズの予報は出さないが、いまのサイズの'
      '上限到達（＝使える見込み）は予報する（ユーザーフィードバックにより追加）',
      () {
        // 24ヶ月・13kg → さらさらケア テープ L(9-14) はゆらぎ [9,11] の外でクリーン最大。
        final child = childWith(ageMonths: 24, weightKg: 13.0);
        final guide = computeDiaperSlotGuide(
          child: child,
          ladder: _ladderOf('pampers_sarasara', DiaperType.tape),
        );

        expect(guide, isNotNull);
        expect(guide!.fit.status, DiaperFitStatus.clean);
        expect(guide.fit.isMaxSize, isTrue);
        expect(guide.nextSizeForecast, isNull);
        expect(guide.nextBand, isNull);
        expect(guide.lowerSizeEndForecast, isNotNull);
        expect(guide.lowerSizeEndForecast!.weeksUntil, greaterThan(0));
      },
    );
  });

  group('週数の表示丸め（買いだめ助言は変更依頼2・§9/追加フィードバックで全廃止）', () {
    test('週数の丸め：6週以下はそのまま、7週以上は2週間刻み', () {
      expect(roundedDiaperWeeks(0), 0);
      expect(roundedDiaperWeeks(4), 4);
      expect(roundedDiaperWeeks(6), 6);
      expect(roundedDiaperWeeks(7), 8);
      expect(roundedDiaperWeeks(8), 8);
      expect(roundedDiaperWeeks(9), 10);
      expect(roundedDiaperWeeks(12), 12);
    });
  });

  group('推奨サイズの繰り上げ（変更依頼2・§7：上限−0.5kg超で次サイズへ）', () {
    test('境界ちょうど（14.0kg・グーン パンツ L9-14/BIG12-22）はゆらぎ中で'
        '大きい方（BIG）が言い切り可の推奨として出る（クリーン＋Lではない）', () {
      // §7の例：14.0kgはLの上限ちょうど。真の重複の接近ロジックにより、
      // すでにゆらぎ中＋言い切り可（＝BIGが推奨）になっていることを確認する。
      // （goon_more0はM/L/BIGの3段のみで、後段の重複干渉が無い単純な例）
      final ladder = _ladderOf('goon_more0', DiaperType.pants);
      final fit = evaluateDiaperFit(ladder: ladder, weightKg: 14.0);
      expect(fit.status, DiaperFitStatus.inTransition);
      expect(fit.assertiveTransition, isTrue);

      final lIndex = ladder.indexWhere((b) => b.sizeLabel == 'L');
      expect(fit.currentIndex, lIndex);
      expect(ladder[fit.currentIndex! + 1].sizeLabel, 'BIG');
    });

    test('体重13.5kg以下ではLがそのまま推奨（繰り上げ前）', () {
      final ladder = _ladderOf('goon_more0', DiaperType.pants);
      final fit = evaluateDiaperFit(ladder: ladder, weightKg: 13.0);
      // L(9-14)/BIG(12-22)は真の重複。13.0kgは重複区間[12,14]の中なので、
      // ゆらぎ中＋言い切り可（Lは既にひとつ前）。
      expect(fit.status, DiaperFitStatus.inTransition);
      expect(fit.assertiveTransition, isTrue);
    });

    test('次のサイズが無い場合（シリーズ最大）は繰り上げ対象外で従来通り', () {
      // グーン（モレ0へ）パンツ BIGははしごの最後（12〜22kg）。
      final ladder = _ladderOf('goon_more0', DiaperType.pants);
      final fit = evaluateDiaperFit(ladder: ladder, weightKg: 21.8);
      expect(fit.status, DiaperFitStatus.clean);
      expect(fit.isMaxSize, isTrue);
      expect(ladder[fit.currentIndex!].sizeLabel, 'BIG');
    });

    test('次のサイズが体重をカバーしていない場合は繰り上げない（事実に基づかない推奨を出さない）', () {
      // 合成データ：隙間1.2kg（現データには存在しないが安全網を直接確認する）。
      // current=4〜6, next=7.2〜10。6.9kgはcurrent上限(6)-0.5=5.5を超えるが、
      // nextの下限(7.2)には届いていないため、繰り上げてはいけない。
      final ladder = [_band('A', 4, 6), _band('B', 7.2, 10)];
      final fit = evaluateDiaperFit(ladder: ladder, weightKg: 6.9);
      // 隙間の中点(6.6)±0.5=[6.1,7.1]の中なので、そもそもゆらぎ中と判定される。
      expect(fit.status, DiaperFitStatus.inTransition);
    });
  });

  group('非表示の提案（トリガーは行動ベースのみ）', () {
    final asOf = DateTime(2026, 7, 18);

    ChildProfile childWith({DateTime? lastOpened, DateTime? lastSuggested}) =>
        ChildProfile(
          id: 'test',
          name: 'テスト',
          birthDate: DateTime(2024, 1, 1),
          gender: Gender.male,
          diaperGuideLastOpenedAt: lastOpened,
          diaperGuideHideSuggestedAt: lastSuggested,
        );

    test('一度も開いた記録が無ければ提案しない', () {
      expect(shouldSuggestHidingDiaperGuide(childWith(), asOf: asOf), isFalse);
    });

    test('90日以上開いていなければ提案、それ未満なら提案しない', () {
      expect(
        shouldSuggestHidingDiaperGuide(
          childWith(lastOpened: asOf.subtract(const Duration(days: 91))),
          asOf: asOf,
        ),
        isTrue,
      );
      expect(
        shouldSuggestHidingDiaperGuide(
          childWith(lastOpened: asOf.subtract(const Duration(days: 30))),
          asOf: asOf,
        ),
        isFalse,
      );
    });

    test('提案後は約6か月あけて再提案する', () {
      final lastOpened = asOf.subtract(const Duration(days: 200));
      expect(
        shouldSuggestHidingDiaperGuide(
          childWith(
            lastOpened: lastOpened,
            lastSuggested: asOf.subtract(const Duration(days: 30)),
          ),
          asOf: asOf,
        ),
        isFalse,
      );
      expect(
        shouldSuggestHidingDiaperGuide(
          childWith(
            lastOpened: lastOpened,
            lastSuggested: asOf.subtract(const Duration(days: 190)),
          ),
          asOf: asOf,
        ),
        isTrue,
      );
    });
  });

  group('ChildProfile の永続化（おむつガイド関連フィールド）', () {
    test('開いた日時・提案日時が JSON を往復して保持される', () {
      final child = ChildProfile(
        id: 'test',
        name: 'テスト',
        birthDate: DateTime(2024, 1, 1),
        gender: Gender.female,
        diaperGuideLastOpenedAt: DateTime(2026, 7, 1),
        diaperGuideHideSuggestedAt: DateTime(2026, 6, 1),
      );

      final restored = ChildProfile.fromJson(child.toJson());
      expect(restored.diaperGuideLastOpenedAt, DateTime(2026, 7, 1));
      expect(restored.diaperGuideHideSuggestedAt, DateTime(2026, 6, 1));
    });

    test('旧バージョンの JSON（キー無し）も安全に読み込める', () {
      final json = ChildProfile(
        id: 'test',
        name: 'テスト',
        birthDate: DateTime(2024, 1, 1),
        gender: Gender.male,
      ).toJson()
        ..remove('diaperGuideLastOpenedAt')
        ..remove('diaperGuideHideSuggestedAt');

      final restored = ChildProfile.fromJson(json);
      expect(restored.diaperGuideLastOpenedAt, isNull);
      expect(restored.diaperGuideHideSuggestedAt, isNull);
    });
  });

  group('全マスタデータの健全性（ロジックがどのはしごでも破綻しない）', () {
    test('全シリーズ×全タイプで区間計算が成功し、区間が min<=max を満たす', () {
      for (final brand in kDiaperBrands) {
        for (final series in brand.series) {
          for (final type in series.availableTypes) {
            final ladder = series.bandsFor(type);
            final transitions = computeDiaperTransitions(ladder);
            expect(transitions.length, ladder.length - 1,
                reason: '${series.id}/$type');
            for (final t in transitions) {
              expect(t.zoneMinKg, lessThanOrEqualTo(t.zoneMaxKg),
                  reason: '${series.id}/$type pair${t.lowerIndex}');
            }
          }
        }
      }
    });

    test('全シリーズ×全タイプ×0〜36kg の全刻みで判定が例外なく返る', () {
      for (final brand in kDiaperBrands) {
        for (final series in brand.series) {
          for (final type in series.availableTypes) {
            final ladder = series.bandsFor(type);
            for (var w = 0.0; w <= 36.0; w += 0.1) {
              final kg = double.parse(w.toStringAsFixed(1));
              final r = evaluateDiaperFit(ladder: ladder, weightKg: kg);
              // クリーン／ゆらぎなら現在地インデックスが必ず有効範囲。
              if (r.status == DiaperFitStatus.clean) {
                expect(r.currentIndex, inInclusiveRange(0, ladder.length - 1),
                    reason: '${series.id}/$type $kg kg');
              } else if (r.status == DiaperFitStatus.inTransition) {
                expect(r.transition, isNotNull,
                    reason: '${series.id}/$type $kg kg');
                expect(r.transition!.lowerIndex,
                    inInclusiveRange(0, ladder.length - 2),
                    reason: '${series.id}/$type $kg kg');
              }
            }
          }
        }
      }
    });
  });
}
