import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// おむつガイドの状態バッジ（アイコン＋短いラベルのピル）。
///
/// シリーズ識別バッジ（3色）とは役割が違い、こちらは状態通知用なので
/// アプリの通常のテキスト色（インク色）1色で表示する。
/// アイコンは Lucide（ISCライセンス）。assets/diaper/icons/status/ に配置。
enum DiaperStatusKind {
  /// ゆらぎ中（サイズアップ間近）。
  sizeUp,

  /// 最大サイズ到達（範囲内）。
  max,

  /// 上限超過。
  exceeds,
}

/// 状態 → アイコンファイル・ラベルの対応（1か所にまとめる）。
const Map<DiaperStatusKind, ({String asset, String label})>
    kDiaperStatusPillSpecs = {
  DiaperStatusKind.sizeUp: (
    asset: 'assets/diaper/icons/status/size-up.svg',
    label: 'サイズUP',
  ),
  DiaperStatusKind.max: (
    asset: 'assets/diaper/icons/status/max.svg',
    label: 'シリーズ最大',
  ),
  DiaperStatusKind.exceeds: (
    asset: 'assets/diaper/icons/status/exceeds.svg',
    label: 'シリーズ上限突破',
  ),
};

class DiaperStatusPill extends StatelessWidget {
  const DiaperStatusPill({super.key, required this.kind});

  final DiaperStatusKind kind;

  /// インク色（アプリの見出しと同系の濃いグレー）。
  static const Color _ink = Color(0xFF444444);

  @override
  Widget build(BuildContext context) {
    final spec = kDiaperStatusPillSpecs[kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ink.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            spec.asset,
            width: 12,
            height: 12,
            colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
          ),
          const SizedBox(width: 4),
          Text(
            spec.label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
