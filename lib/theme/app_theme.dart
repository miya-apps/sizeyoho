import 'package:flutter/material.dart';

/// 子供のテーマカラー（くすみパステル）から ThemeData を生成する。
///
/// - [primary]          : seedColor そのまま（ボタン・アクセントなど小面積）
/// - [primaryContainer] : seedColor に白を50%混ぜた明るい色（ヘッダー等大面積）
/// - [onPrimary] /
///   [onPrimaryContainer]: seedColor を暗くした濃いグレー（視認性確保）
/// - Scaffold 背景     : seedColor を94%白に薄めたオフホワイト
ThemeData createChildTheme(Color seedColor) {
  final headerBg = Color.lerp(seedColor, Colors.white, 0.50)!;
  final headerFg = Color.lerp(seedColor, Colors.black, 0.60)!;
  final scaffoldBg = Color.lerp(seedColor, Colors.white, 0.94)!;

  final base = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );
  final cs = base.copyWith(
    primary: seedColor,
    onPrimary: headerFg,
    primaryContainer: headerBg,
    onPrimaryContainer: headerFg,
    surface: scaffoldBg,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: scaffoldBg,
  );

  return ThemeData(
    useMaterial3: true,
    // アプリ全体の書体。アイコンの文字と同じ丸ゴシック（Zen Maru Gothic）。
    fontFamily: 'ZenMaruGothic',
    colorScheme: cs,
    scaffoldBackgroundColor: scaffoldBg,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

/// アプリ全体のテーマを保持するノティファイア。
final appThemeNotifier = ValueNotifier<ThemeData>(
  createChildTheme(const Color(0xFF7FA6D6)),
);
