import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/growth/diaper_master.dart';
import 'package:grow_app/widgets/diaper_badge.dart';

/// バッジSVGの組み立てロジックのテスト。
/// 色はハードコードせず、渡した3色がそのまま出力へ反映されることを確認する。
void main() {
  const colors = DiaperBadgeColors(
    bg: '#01B3AE',
    icon: '#FFFFFF',
    ring: '#FA7283',
  );

  test('category → アイコンの対応表が5種そろっている', () {
    expect(kDiaperBadgeIconFiles[''], 'diaper.svg');
    expect(kDiaperBadgeIconFiles['night'], 'moon-stars.svg');
    expect(kDiaperBadgeIconFiles['swim'], 'water-gun.svg');
    expect(kDiaperBadgeIconFiles['training'], 'toilet-paper.svg');
    expect(kDiaperBadgeIconFiles['duration'], 'clock.svg');
    // 太さ・縮小率の対応表もアイコン全種をカバーしている。
    for (final file in kDiaperBadgeIconFiles.values) {
      expect(kDiaperBadgeStrokeWidths.containsKey(file), isTrue, reason: file);
      expect(kDiaperBadgeIconScales.containsKey(file), isTrue, reason: file);
    }
  });

  test('通常アイコン：リング・背景・塗り＋輪郭線の構造で3色が反映される', () {
    final svg = buildDiaperBadgeSvg(
      colors: colors,
      iconFileName: 'diaper.svg',
      iconInner: '<path d="M0 0" />',
    );
    // 外周リング（r=24）と背景（r=21.25）。
    expect(svg, contains('r="24" fill="#FA7283"'));
    expect(svg, contains('r="21.25" fill="#01B3AE"'));
    // アイコンは塗り＝icon色、線＝ring色、太さ1.1、scale(1.6)。
    expect(svg, contains('scale(1.6)'));
    expect(svg, contains('fill="#FFFFFF" stroke="#FA7283" stroke-width="1.1"'));
  });

  test('water-gun：0.8倍の入れ子と、縮小を打ち消す線の太さ1.375', () {
    final svg = buildDiaperBadgeSvg(
      colors: colors,
      iconFileName: 'water-gun.svg',
      iconInner: '<path d="M0 0" />',
    );
    expect(svg, contains('translate(12,12) scale(0.8) translate(-12,-12)'));
    expect(svg, contains('stroke-width="1.375"'));
  });
}
