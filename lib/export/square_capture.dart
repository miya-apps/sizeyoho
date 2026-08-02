import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 任意のウィジェットを「正方形」の画像として書き出す共通ヘルパー。
///
/// Instagram の正方形投稿にそのまま使えるよう、一辺 [contentWidth] の
/// 固定サイズの正方形キャンバスに描画する（内容量に関わらず毎回同じ
/// 大きさの正方形になる）。
///
/// コンテンツは幅 [contentWidth] で自然な高さにレイアウトし、
/// - 正方形より低い場合：上下の余白を背景色で埋めて中央に置く
/// - 正方形より高い場合：FittedBox（scaleDown）で全体を比例縮小して収める
///
/// 描画は従来どおり「Overlay の画面外に1フレームだけ置いて PNG 化する」
/// 方式（RepaintBoundary.toImage は画面のクリッピングに関係なく
/// そのレイヤー全体を描くため、画面サイズの影響を受けない）。
Future<Uint8List?> captureSquareImage({
  required BuildContext context,
  required WidgetBuilder contentBuilder,
  required double contentWidth,
  Color background = Colors.white,
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final squareKey = GlobalKey();
  final side = contentWidth;

  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: -side * 3,
      top: 0,
      width: side,
      height: side,
      child: RepaintBoundary(
        key: squareKey,
        child: Container(
          width: side,
          height: side,
          color: background,
          alignment: Alignment.center,
          // scaleDown なので、収まる場合は等倍のまま中央寄せ、
          // 収まらない場合だけ縮小される（拡大はしない）。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: contentWidth,
              child: contentBuilder(ctx),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    // レイアウトと描画が終わるまで待つ（余裕をみて2フレーム）。
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final render = squareKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return null;
    final image = await render.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
