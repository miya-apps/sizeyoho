import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../growth/diaper_master.dart';

/// おむつシリーズの識別バッジ（3色＋アイコン）。
///
/// 設計方針（cursor-prompt-omutsu-changes-1.md 変更2）：
/// - シリーズごとに画像を作り置きせず、5つのアイコンSVGと CSV 由来の3色から
///   実行時に合成する（CSVの色を差し替えるだけで反映される）。
/// - 色をコードにハードコードしない。必ずマスタデータ（CSV由来）から読む。
/// - ロゴ画像は使わない。ユーザーの入力・権限・保存は一切増やさない。
/// - 全アイコン「塗り＋細い輪郭線」方式：塗り＝badge_color_icon、
///   線＝badge_color_ring（外周リングと兼任）。

/// category 値 → アイコンファイル名。空＝通常品（diaper.svg）。
/// 想定外の値が来た場合も diaper.svg にフォールバックする
/// （タイプミスは生成スクリプトとユニットテストが検出する）。
const Map<String, String> kDiaperBadgeIconFiles = {
  '': 'diaper.svg',
  'night': 'moon-stars.svg',
  'swim': 'water-gun.svg',
  'training': 'toilet-paper.svg',
  'duration': 'clock.svg',
};

/// アイコン名 → 輪郭線の太さ。全アイコン 1.1 で問題ないことを実測済みだが、
/// 個別に変える必要が生じた場合はこの表だけを直す（ハードコードで散らさない）。
const Map<String, double> kDiaperBadgeStrokeWidths = {
  'diaper.svg': 1.1,
  'moon-stars.svg': 1.1,
  'water-gun.svg': 1.1,
  'toilet-paper.svg': 1.1,
  'clock.svg': 1.1,
};

/// アイコン名 → 追加の縮小補正率。
/// water-gun.svg（Streamline）だけ 24×24 枠に対する絵柄の使用率が 94% と
/// 大きく（Tabler Icons 由来の4つは 75% 程度）、同じ倍率だと窮屈に見える
/// ため 0.8 倍に縮める。線の太さは縮小率で割って見た目を他と揃える。
const Map<String, double> kDiaperBadgeIconScales = {
  'diaper.svg': 1.0,
  'moon-stars.svg': 1.0,
  'water-gun.svg': 0.8,
  'toilet-paper.svg': 1.0,
  'clock.svg': 1.0,
};

/// アイコンSVGの中身（<svg> の内側）のキャッシュ。アイコンは5個の静的
/// アセットなので、一度読めばアプリ終了まで使い回せる。
final Map<String, Future<String>> _iconInnerCache = {};

Future<String> _loadIconInner(String fileName) =>
    _iconInnerCache.putIfAbsent(fileName, () async {
      final raw =
          await rootBundle.loadString('assets/diaper/icons/$fileName');
      return _extractSvgInner(raw);
    });

/// SVG から <svg> タグの内側だけを取り出す。
/// コメント（<!-- -->）と <desc>...</desc>（説明文）は必ず除去する
/// （視覚的には出ないが、余計な要素として混入しやすいため）。
String _extractSvgInner(String raw) {
  var s = raw
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(RegExp(r'<desc>[\s\S]*?</desc>'), '');
  final open = s.indexOf(RegExp(r'<svg[\s\S]*?>'));
  final openEnd = s.indexOf('>', open);
  final close = s.lastIndexOf('</svg>');
  s = s.substring(openEnd + 1, close);
  return s.trim();
}

/// バッジ全体のSVG文字列を組み立てる。
///
/// 構造：外周リング（円）＋背景（円）＋拡大配置したアイコン。
/// - リングは細め（内円半径 21.25 / 外周 24）
/// - アイコンは 24×24 素材を scale(1.6) で拡大して中央配置
/// - アイコンは「塗り＋細い輪郭線」：fill=アイコン色、stroke=リング色
String buildDiaperBadgeSvg({
  required DiaperBadgeColors colors,
  required String iconFileName,
  required String iconInner,
}) {
  final strokeWidth = kDiaperBadgeStrokeWidths[iconFileName] ?? 1.1;
  final scale = kDiaperBadgeIconScales[iconFileName] ?? 1.0;

  // 縮小補正をかける場合は、線の太さを補正率で割って見た目の太さを揃える。
  final String iconGroup;
  if (scale != 1.0) {
    final adjustedWidth = strokeWidth / scale;
    iconGroup = '''
  <g transform="translate(4.8,4.8) scale(1.6)">
    <g transform="translate(12,12) scale($scale) translate(-12,-12)"
       fill="${colors.icon}" stroke="${colors.ring}" stroke-width="$adjustedWidth"
       stroke-linecap="round" stroke-linejoin="round">
      $iconInner
    </g>
  </g>''';
  } else {
    iconGroup = '''
  <g transform="translate(4.8,4.8) scale(1.6)"
     fill="${colors.icon}" stroke="${colors.ring}" stroke-width="$strokeWidth"
     stroke-linecap="round" stroke-linejoin="round">
    $iconInner
  </g>''';
  }

  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="24" fill="${colors.ring}"/>
  <circle cx="24" cy="24" r="21.25" fill="${colors.bg}"/>
$iconGroup
</svg>''';
}

/// シリーズ識別バッジ。同一シリーズ（＋同一タイプ・性別）なら、
/// 画面のどこに出しても同じ見た目になる。
class DiaperBadge extends StatelessWidget {
  const DiaperBadge({
    super.key,
    required this.series,
    this.type,
    this.isBoy,
    this.size = 26,
  });

  final DiaperSeries series;

  /// 選択中のタイプ（タイプ別の配色があるシリーズで使う）。
  /// 未選択の一覧などでは null（ベース色になる）。
  final DiaperType? type;

  /// 子どもの性別（男児色・女児色があるシリーズで使う）。null ならベース色。
  final bool? isBoy;

  /// 表示サイズ（論理ピクセル）。
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = series.badgeColorsFor(type: type, isBoy: isBoy);
    final iconFile =
        kDiaperBadgeIconFiles[series.category] ?? 'diaper.svg';

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<String>(
        future: _loadIconInner(iconFile),
        builder: (context, snapshot) {
          final inner = snapshot.data;
          if (inner == null) {
            // 読み込み完了までの一瞬だけ、アイコン無しの2円を出す
            // （サイズが変わらないためレイアウトは動かない）。
            return DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _parseHex(colors.bg),
                border: Border.all(
                  color: _parseHex(colors.ring),
                  width: size / 24,
                ),
              ),
            );
          }
          return SvgPicture.string(
            buildDiaperBadgeSvg(
              colors: colors,
              iconFileName: iconFile,
              iconInner: inner,
            ),
            width: size,
            height: size,
          );
        },
      ),
    );
  }

  static Color _parseHex(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
