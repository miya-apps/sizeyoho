import 'dart:typed_data';

import 'package:flutter/material.dart';

/// お誕生日写真の共通表示。
/// どの画面でも「正方形＋ユーザーが調整した切り取り位置・拡大率」で
/// 統一して表示する。
class BirthdayPhoto extends StatelessWidget {
  const BirthdayPhoto({
    super.key,
    required this.bytes,
    this.alignX = 0.0,
    this.alignY = 0.0,
    this.scale = 1.0,
    this.borderRadius = 12,
  });

  final Uint8List bytes;

  /// 切り取り位置（-1.0〜1.0、0 が中央）。
  final double alignX;
  final double alignY;

  /// 拡大率（1.0＝正方形いっぱい、それ以上でズームイン）。
  final double scale;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(
      alignX.clamp(-1.0, 1.0),
      alignY.clamp(-1.0, 1.0),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxWidth * scale.clamp(1.0, 8.0);
            // 拡大分のはみ出しは OverflowBox 側の alignment、
            // 写真の縦横比によるはみ出しは Image(cover) 側の alignment が
            // それぞれ受け持つ。同じ値を渡すことで、align=±1 がちょうど
            // 写真の端になる（縦横比を知らなくても全域をパンできる）。
            return OverflowBox(
              minWidth: side,
              maxWidth: side,
              minHeight: side,
              maxHeight: side,
              alignment: alignment,
              child: Image.memory(
                bytes,
                width: side,
                height: side,
                fit: BoxFit.cover,
                alignment: alignment,
                gaplessPlayback: true,
              ),
            );
          },
        ),
      ),
    );
  }
}
