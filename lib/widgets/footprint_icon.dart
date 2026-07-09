import 'package:flutter/material.dart';

/// 指5本が見える「足あと」アイコン。
///
/// 既製アイコン（Phosphor の footprints）は指がなく靴の中敷きに
/// 見えてしまうため、赤ちゃんの足形らしい形を独自に描画する。
/// 色は [color] 未指定なら IconTheme に従う（ボタン内でも正しく効く）。
class FootprintIcon extends StatelessWidget {
  const FootprintIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black87;
    return CustomPaint(
      size: Size.square(size),
      painter: _FootprintPainter(c),
    );
  }
}

class _FootprintPainter extends CustomPainter {
  const _FootprintPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    // 左右の足を少し互い違いに（歩いた足あとらしく）。
    _foot(canvas, paint, s, cx: 7.6, top: 8.4, mirror: false);
    _foot(canvas, paint, s, cx: 16.4, top: 1.6, mirror: true);
  }

  /// 片足を描く。[mirror] が true なら右足（親指が左側）。
  void _foot(
    Canvas canvas,
    Paint paint,
    double s, {
    required double cx,
    required double top,
    required bool mirror,
  }) {
    final m = mirror ? -1.0 : 1.0;
    // 指5本：内側（親指）がいちばん大きく、外へ向かって小さく。
    const toes = [
      [2.35, 1.30, 1.05], // dx, dy, 半径（親指）
      [0.80, 0.35, 0.80],
      [-0.65, 0.15, 0.70],
      [-1.95, 0.35, 0.62],
      [-3.05, 0.90, 0.55],
    ];
    for (final t in toes) {
      canvas.drawCircle(
        Offset((cx + m * t[0]) * s, (top + t[1]) * s),
        t[2] * s,
        paint,
      );
    }
    // 足裏：つま先側が広く、かかとが細い（楕円2つを重ねて表現）。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx * s, (top + 5.5) * s),
        width: 6.6 * s,
        height: 5.6 * s,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset((cx + m * 0.3) * s, (top + 9.6) * s),
        width: 4.4 * s,
        height: 5.2 * s,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FootprintPainter oldDelegate) =>
      oldDelegate.color != color;
}
