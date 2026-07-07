import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 表示中の画面（RepaintBoundary 配下）を PNG 画像として取り出すヘルパー。
///
/// AppShell の body を [boundaryKey] 付きの RepaintBoundary で包んでおき、
/// エクスポート時に [capturePng] を呼ぶ。ボトムシートや FAB・下部メニューは
/// boundary の外にあるため画像には写らない。
///
/// キャプチャ後、背景色だけの余白（大画面での左右センタリング余白や、
/// コンテンツが短いときの下部余白）を自動検出して切り落とし、
/// 周囲に [_marginLogical] ぶんだけ均等な余白を残す。
class ScreenCapture {
  ScreenCapture._();

  static final GlobalKey boundaryKey = GlobalKey();

  /// トリミング後にコンテンツの周囲へ残す余白（論理px）。
  static const double _marginLogical = 12;

  /// 背景色との一致判定の許容差（RGB 各チャンネル、0〜255）。
  static const int _bgTolerance = 10;

  /// 現在の画面を余白トリミング済みの PNG バイト列にする。失敗時は null。
  static Future<Uint8List?> capturePng({double pixelRatio = 3.0}) async {
    final context = boundaryKey.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    final full = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final trimmed = await _trimBackground(
        full,
        margin: (_marginLogical * pixelRatio).round(),
      );
      try {
        final byteData = await trimmed.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return byteData?.buffer.asUint8List();
      } finally {
        if (!identical(trimmed, full)) trimmed.dispose();
      }
    } finally {
      full.dispose();
    }
  }

  /// 画像の外周から「背景色のみの行・列」を検出して切り落とす。
  /// 背景色は左上ピクセル（body の塗り色）を基準にする。
  static Future<ui.Image> _trimBackground(
    ui.Image image, {
    required int margin,
  }) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return image;
    final bytes = data.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final bgR = bytes[0];
    final bgG = bytes[1];
    final bgB = bytes[2];

    bool isBg(int x, int y) {
      final i = (y * w + x) * 4;
      return (bytes[i] - bgR).abs() <= _bgTolerance &&
          (bytes[i + 1] - bgG).abs() <= _bgTolerance &&
          (bytes[i + 2] - bgB).abs() <= _bgTolerance;
    }

    bool rowIsBg(int y) {
      for (var x = 0; x < w; x++) {
        if (!isBg(x, y)) return false;
      }
      return true;
    }

    var top = 0;
    while (top < h && rowIsBg(top)) {
      top++;
    }
    // 全面が背景（何も描かれていない）なら元画像のまま返す。
    if (top == h) return image;

    var bottom = h - 1;
    while (bottom > top && rowIsBg(bottom)) {
      bottom--;
    }

    bool colIsBg(int x) {
      for (var y = top; y <= bottom; y++) {
        if (!isBg(x, y)) return false;
      }
      return true;
    }

    var left = 0;
    while (left < w && colIsBg(left)) {
      left++;
    }
    var right = w - 1;
    while (right > left && colIsBg(right)) {
      right--;
    }

    // 周囲に均等な余白を残す（画像端は超えない）。
    left = (left - margin).clamp(0, w - 1);
    right = (right + margin).clamp(0, w - 1);
    top = (top - margin).clamp(0, h - 1);
    bottom = (bottom + margin).clamp(0, h - 1);

    if (left == 0 && top == 0 && right == w - 1 && bottom == h - 1) {
      return image;
    }
    return _crop(
      image,
      ui.Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        (right + 1).toDouble(),
        (bottom + 1).toDouble(),
      ),
    );
  }

  static Future<ui.Image> _crop(ui.Image src, ui.Rect rect) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      src,
      rect,
      ui.Rect.fromLTWH(0, 0, rect.width, rect.height),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(rect.width.round(), rect.height.round());
    } finally {
      picture.dispose();
    }
  }
}
