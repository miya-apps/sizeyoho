import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/growth/diaper_master.dart';
import 'package:grow_app/growth/diaper_master_data.g.dart';

/// マスタデータ（生成物）の整合性テスト。
///
/// CSV 更新→再生成時の事故防止が目的。
/// 注意: 隣接サイズ帯の重複・内包は【正常】なので検証しない
/// （ゆらぎ判定ロジック側で処理する）。隙間だけは入力ミスの可能性が
/// 高いため警告として出力する（テストは落とさない）。
void main() {
  // 全シリーズ×タイプのはしごを列挙するヘルパ。
  Iterable<({DiaperBrand brand, DiaperSeries series, DiaperType type, List<DiaperSizeBand> ladder})>
      allLadders() sync* {
    for (final brand in kDiaperBrands) {
      for (final series in brand.series) {
        for (final type in series.availableTypes) {
          yield (
            brand: brand,
            series: series,
            type: type,
            ladder: series.bandsFor(type),
          );
        }
      }
    }
  }

  test('マスタデータが空でない', () {
    expect(kDiaperBrands, isNotEmpty);
    for (final brand in kDiaperBrands) {
      expect(brand.series, isNotEmpty, reason: 'ブランド ${brand.id} にシリーズがない');
      for (final series in brand.series) {
        expect(series.bands, isNotEmpty, reason: 'シリーズ ${series.id} にサイズがない');
      }
    }
  });

  test('各帯について minKg < maxKg', () {
    for (final l in allLadders()) {
      for (final band in l.ladder) {
        expect(band.minKg, lessThan(band.maxKg),
            reason: '${l.series.id}/${l.type.name}/${band.sizeLabel}');
      }
    }
  });

  test('はしご順に minKg が非減少・同値なら maxKg が厳密増加', () {
    for (final l in allLadders()) {
      for (var i = 1; i < l.ladder.length; i++) {
        final prev = l.ladder[i - 1];
        final cur = l.ladder[i];
        final where =
            '${l.series.id}/${l.type.name}: ${prev.sizeLabel}→${cur.sizeLabel}';
        expect(cur.minKg, greaterThanOrEqualTo(prev.minKg), reason: where);
        if (cur.minKg == prev.minKg) {
          expect(cur.maxKg, greaterThan(prev.maxKg), reason: where);
        }
      }
    }
  });

  test('隙間があれば警告する（テストは落とさない・重複/内包は正常）', () {
    final gaps = <String>[];
    for (final l in allLadders()) {
      for (var i = 1; i < l.ladder.length; i++) {
        final prev = l.ladder[i - 1];
        final cur = l.ladder[i];
        if (cur.minKg > prev.maxKg) {
          gaps.add('${l.series.id}/${l.type.name}: '
              '${prev.sizeLabel}(〜${prev.maxKg}kg) と '
              '${cur.sizeLabel}(${cur.minKg}kg〜) の間に隙間');
        }
      }
    }
    for (final g in gaps) {
      // ignore: avoid_print
      print('警告: $g（入力ミスでないか確認してください）');
    }
  });

  test('sourceUrl と lastChecked が空でない', () {
    for (final brand in kDiaperBrands) {
      for (final series in brand.series) {
        expect(series.sourceUrl, isNotEmpty, reason: series.id);
        expect(series.lastChecked, isNotEmpty, reason: series.id);
        // ISO 形式として解釈できること（lastCheckedAt が例外を投げない）。
        expect(series.lastCheckedAt, isA<DateTime>(), reason: series.id);
      }
    }
  });

  test('series の brandId が親ブランドと一致する（参照整合）', () {
    for (final brand in kDiaperBrands) {
      for (final series in brand.series) {
        expect(series.brandId, brand.id, reason: series.id);
      }
    }
  });

  group('表示名の解決', () {
    DiaperBrand brandOf(String brandId) =>
        kDiaperBrands.firstWhere((b) => b.id == brandId);
    DiaperSeries seriesOf(String seriesId) => kDiaperBrands
        .expand((b) => b.series)
        .firstWhere((s) => s.id == seriesId);

    test('原則はブランド名＋シリーズ名', () {
      expect(
        diaperDisplayName(
          brand: brandOf('pampers'),
          series: seriesOf('pampers_hadaichi'),
          type: DiaperType.tape,
        ),
        'パンパース 肌へのいちばん',
      );
    });

    test('シリーズ名がブランド名で始まる場合は二重にしない', () {
      // マミーポコ ＋ マミーポコ夜用 → 「マミーポコ夜用」
      expect(
        diaperDisplayName(
          brand: brandOf('mamypoko'),
          series: seriesOf('mamypoko_night'),
          type: DiaperType.pants,
        ),
        'マミーポコ夜用',
      );
      // ブランド名と同名のシリーズも二重にならない。
      expect(
        diaperDisplayName(
          brand: brandOf('goon'),
          series: seriesOf('goon_more0'),
          type: DiaperType.pants,
        ),
        'グーン',
      );
    });

    test('タイプ別の商品名があるシリーズは選んだタイプの名前を使う', () {
      final moony = seriesOf('moony');
      expect(moony.seriesNameFor(DiaperType.tape), 'ムーニー');
      expect(moony.seriesNameFor(DiaperType.pants), 'ムーニーマン');
      // ムーニーはブランド名で始まるので表示名もシリーズ名のみ。
      expect(
        diaperDisplayName(
          brand: brandOf('moony'),
          series: moony,
          type: DiaperType.pants,
        ),
        'ムーニーマン',
      );

      final nishimatsuya = seriesOf('nishimatsuya_baby');
      expect(nishimatsuya.seriesNameFor(DiaperType.tape), 'ベビーおむつ テープ');
      expect(nishimatsuya.seriesNameFor(DiaperType.pants), 'ベビーパンツ');
      expect(
        diaperDisplayName(
          brand: brandOf('nishimatsuya'),
          series: nishimatsuya,
          type: DiaperType.pants,
        ),
        '西松屋 ベビーパンツ',
      );
    });

    test('タイプ別名のないシリーズはどちらのタイプでも同じ名前', () {
      final sarasara = seriesOf('pampers_sarasara');
      expect(sarasara.seriesNameFor(DiaperType.tape), 'さらさらケア');
      expect(sarasara.seriesNameFor(DiaperType.pants), 'さらさらケア');
    });
  });

  group('シリーズ識別バッジ（3色＋アイコン）', () {
    DiaperSeries seriesOf(String seriesId) => kDiaperBrands
        .expand((b) => b.series)
        .firstWhere((s) => s.id == seriesId);

    final hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

    Iterable<DiaperSeries> allSeries() =>
        kDiaperBrands.expand((b) => b.series);

    test('category が想定値（night/swim/training/duration/空）のいずれか', () {
      const valid = {'', 'night', 'swim', 'training', 'duration'};
      for (final series in allSeries()) {
        // 想定外の値はタイプミス。表示側は diaper.svg にフォールバックするが
        // データとしては誤りなのでテストを落とす。
        expect(valid.contains(series.category), isTrue,
            reason: '${series.id}: category "${series.category}" は想定外');
      }
    });

    test('ベース3色がすべて #RRGGBB 形式で空でない', () {
      for (final series in allSeries()) {
        expect(series.badgeColors.bg, matches(hexColor), reason: series.id);
        expect(series.badgeColors.icon, matches(hexColor), reason: series.id);
        expect(series.badgeColors.ring, matches(hexColor), reason: series.id);
      }
    });

    test('badge_color_bg と badge_color_icon が同一でない（溶け込み防止）', () {
      for (final series in allSeries()) {
        expect(
          series.badgeColors.bg.toUpperCase(),
          isNot(series.badgeColors.icon.toUpperCase()),
          reason: series.id,
        );
      }
    });

    test('上書き色も #RRGGBB 形式（存在する場合のみ）', () {
      for (final series in allSeries()) {
        for (final colors in [
          series.badgeColorsTape,
          series.badgeColorsPants,
          series.badgeColorsBoy,
          series.badgeColorsGirl,
        ]) {
          if (colors == null) continue;
          expect(colors.bg, matches(hexColor), reason: series.id);
          expect(colors.icon, matches(hexColor), reason: series.id);
          expect(colors.ring, matches(hexColor), reason: series.id);
          expect(colors.bg.toUpperCase(), isNot(colors.icon.toUpperCase()),
              reason: series.id);
        }
      }
    });

    test('タイプ別上書きと性別別上書きを同時に持つシリーズがない（優先順位未定義）', () {
      for (final series in allSeries()) {
        final hasType =
            series.badgeColorsTape != null || series.badgeColorsPants != null;
        final hasGender =
            series.badgeColorsBoy != null || series.badgeColorsGirl != null;
        expect(hasType && hasGender, isFalse, reason: series.id);
      }
    });

    test('色の解決：上書きなしのシリーズはタイプ・性別によらずベース色', () {
      final sarasara = seriesOf('pampers_sarasara');
      for (final type in [null, DiaperType.tape, DiaperType.pants]) {
        for (final isBoy in [null, true, false]) {
          expect(
            sarasara.badgeColorsFor(type: type, isBoy: isBoy),
            same(sarasara.badgeColors),
          );
        }
      }
    });

    test('色の解決：トレパンマンは性別で色が変わる', () {
      final trepan = seriesOf('moony_trepan');
      expect(trepan.badgeColorsBoy, isNotNull);
      expect(trepan.badgeColorsGirl, isNotNull);
      expect(
        trepan.badgeColorsFor(isBoy: true),
        same(trepan.badgeColorsBoy),
      );
      expect(
        trepan.badgeColorsFor(isBoy: false),
        same(trepan.badgeColorsGirl),
      );
      // 性別未指定ならベース色にフォールバック。
      expect(trepan.badgeColorsFor(), same(trepan.badgeColors));
    });
  });

  group('体重帯の表示（範囲併記）', () {
    test('通常サイズは「min〜maxkg」', () {
      expect(
        diaperRangeLabel(const DiaperSizeBand(sizeLabel: 'L', minKg: 9, maxKg: 14)),
        '9〜14kg',
      );
      expect(
        diaperRangeLabel(
            const DiaperSizeBand(sizeLabel: 'S', minKg: 3.5, maxKg: 8)),
        '3.5〜8kg',
      );
    });

    test('新生児サイズ（0スタート）は 0 を表示しない', () {
      expect(
        diaperRangeLabel(
            const DiaperSizeBand(sizeLabel: '新生児', minKg: 0, maxKg: 5)),
        '〜5kg',
      );
    });
  });

  group('タイプの動的判定（ハードコードなし）', () {
    DiaperSeries seriesOf(String seriesId) => kDiaperBrands
        .expand((b) => b.series)
        .firstWhere((s) => s.id == seriesId);

    test('両タイプ持ちのシリーズ', () {
      expect(seriesOf('moony').hasBothTypes, isTrue);
      expect(seriesOf('pampers_sarasara').hasBothTypes, isTrue);
    });

    test('グーン(モレ0へ)にテープタイプがあり BIG(XL) 12〜20kg まで持つ', () {
      final more0 = seriesOf('goon_more0');
      expect(more0.hasBothTypes, isTrue);
      final tape = more0.bandsFor(DiaperType.tape);
      expect(tape, hasLength(5));
      expect(tape.last.sizeLabel, 'BIG(XL)');
      expect(tape.last.minKg, 12);
      expect(tape.last.maxKg, 20);
    });

    test('片タイプのみのシリーズはタイプ選択をスキップできる', () {
      final oyasumi = seriesOf('pampers_oyasumi');
      expect(oyasumi.hasBothTypes, isFalse);
      expect(oyasumi.availableTypes, [DiaperType.pants]);
      expect(oyasumi.bandsFor(DiaperType.tape), isEmpty);
    });

    test('はしごが1段しかないシリーズ・タイプが存在し得る', () {
      // グーン スーパーBIG はテープ・パンツとも1サイズのみ。
      final superBig = seriesOf('goon_superbig');
      expect(superBig.bandsFor(DiaperType.tape), hasLength(1));
      expect(superBig.bandsFor(DiaperType.pants), hasLength(1));
    });
  });
}
