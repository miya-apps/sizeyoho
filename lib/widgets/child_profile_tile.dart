import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../models/gender.dart';

class ChildProfileTile extends StatelessWidget {
  const ChildProfileTile({
    super.key,
    required this.child,
    required this.onEdit,
    this.trailing,
  });

  static const kThemeColors = [
    // 青のみ彩度を高め（41%→52%）、グレーに見えないようにする（明度は他と同等）。
    Color(0xFF7FA6D6),
    Color(0xFFDDA0AA),
    Color(0xFFEEDC9A),
    Color(0xFFA3B899),
    Color(0xFFE4A99B),
    Color(0xFFC5B9CD),
  ];

  final ChildProfile child;
  final VoidCallback onEdit;

  /// 編集ボタンの右に置く追加ウィジェット（並び替えのドラッグハンドルなど）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeColor = child.themeColor;
    final avatarBg = Color.lerp(themeColor, Colors.white, 0.55)!;
    final avatarFg = Color.lerp(themeColor, Colors.black, 0.45)!;

    final Widget avatar = child.photoBytes != null
        ? CircleAvatar(
            radius: 24,
            backgroundImage: MemoryImage(child.photoBytes!),
          )
        : CircleAvatar(
            radius: 24,
            backgroundColor: avatarBg,
            child: Icon(
              kChildIconOptions[
                  child.iconIndex.clamp(0, kChildIconOptions.length - 1)],
              color: avatarFg,
              size: 24,
            ),
          );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          child.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${child.age}歳',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    child.gender.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'プロフィールを編集',
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
