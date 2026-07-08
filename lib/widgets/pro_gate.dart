import 'dart:ui';

import 'package:flutter/material.dart';

import '../monetization/pro_paywall.dart';
import '../monetization/pro_status.dart';

/// Pro限定コンテンツのゲート。
///
/// Pro版なら [child] をそのまま表示する。無料版では [child] を
/// ぼかして鍵アイコンを重ね、タップでペイウォール（料金案内）を開く。
/// ぼかしの下の実データはスクリーンリーダーからも読めないよう
/// セマンティクスを除外する。
class ProGate extends StatelessWidget {
  const ProGate({
    super.key,
    required this.child,
    this.lockLabel = 'Pro版で見る',
    this.borderRadius,
  });

  final Widget child;

  /// 鍵アイコンの横に出す短い案内。
  final String lockLabel;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ProStatus.isPro,
      builder: (context, isPro, _) {
        if (isPro) return child;
        final radius = borderRadius ?? BorderRadius.circular(10);
        return ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: child,
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.4),
                  child: InkWell(
                    onTap: () => showProPaywallSheet(context),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 15,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(width: 5),
                          Text(
                            lockLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
