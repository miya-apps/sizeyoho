import 'package:flutter/material.dart';

/// 指5本が見える「足あと」アイコン（肌色）。
///
/// 既製アイコン（Phosphor の footprints）は指がなく靴の中敷きに
/// 見えてしまうため、赤ちゃんの足形らしい形を独自に描画する。
/// 淡い背景でも境界が分かるよう、薄い縁取りとグラデーションを付ける。
class FootprintIcon extends StatelessWidget {
  const FootprintIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _FootprintPainter(),
    );
  }
}

class _FootprintPainter extends CustomPainter {
  const _FootprintPainter();

  static const _outline = Color(0xFF9A6B52);
  static const _highlight = Color(0xFFF8DCC8);
  static const _base = Color(0xFFE8B498);
  static const _shadow = Color(0xFFD49578);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final bounds = Offset.zero & size;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_highlight, _base, _shadow],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bounds)
      ..isAntiAlias = true;
    final outlinePaint = Paint()
      ..color = _outline
      ..isAntiAlias = true;

    // 縁取り → 肌色の順で重ねて、背景色に溶け込まないようにする。
    _foot(canvas, outlinePaint, s, cx: 7.6, top: 8.4, mirror: false, inflate: 0.14);
    _foot(canvas, outlinePaint, s, cx: 16.4, top: 1.6, mirror: true, inflate: 0.14);
    _foot(canvas, fillPaint, s, cx: 7.6, top: 8.4, mirror: false, inflate: 0);
    _foot(canvas, fillPaint, s, cx: 16.4, top: 1.6, mirror: true, inflate: 0);
  }

  /// 片足を描く。[mirror] が true なら右足（親指が左側）。
  void _foot(
    Canvas canvas,
    Paint paint,
    double s, {
    required double cx,
    required double top,
    required bool mirror,
    required double inflate,
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
        (t[2] + inflate) * s,
        paint,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx * s, (top + 5.5) * s),
        width: (6.6 + inflate * 2) * s,
        height: (5.6 + inflate * 2) * s,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset((cx + m * 0.3) * s, (top + 9.6) * s),
        width: (4.4 + inflate * 2) * s,
        height: (5.2 + inflate * 2) * s,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FootprintPainter oldDelegate) => false;
}
