import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../models/gender.dart';

// 選択タブと同じ高さにし、タブ上の無駄な余白（旧 48-40=8px）を解消する。
const _kTabBarHeight = 40.0;
const _kSelectedTabHeight = 40.0;
const _kUnselectedTabHeight = 32.0;
const _kTabTopRadius = 16.0;

/// お子様切り替えタブを含むカスタムヘッダー（インデックスタブ風）。
class ChildSelectionHeader extends StatelessWidget {
  const ChildSelectionHeader({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddChild,
    this.accentColor,
  });

  final List<ChildProfile> children;
  final int selectedIndex;
  final void Function(int index) onSelect;
  final VoidCallback onAddChild;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final selectedChild = children[selectedIndex.clamp(0, children.length - 1)];

    // 上端の SafeArea は親（AppShell）が一括適用するため、ここでは適用しない
    // （二重 SafeArea によるインセット処理の不安定さを避ける）。
    return SizedBox(
      height: _kTabBarHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ChildSelectionTabBar(
          children: children,
          selectedIndex: selectedIndex,
          onSelect: onSelect,
          onAddChild: onAddChild,
          accentColor: accentColor ?? selectedChild.themeColor,
          canAddChild: children.length < 6,
        ),
      ),
    );
  }
}

/// 横スクロール可能なインデックスタブバー（左寄せ）。
class ChildSelectionTabBar extends StatelessWidget {
  const ChildSelectionTabBar({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddChild,
    required this.accentColor,
    this.canAddChild = true,
  });

  final List<ChildProfile> children;
  final int selectedIndex;
  final void Function(int index) onSelect;
  final VoidCallback onAddChild;
  final Color accentColor;
  final bool canAddChild;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            _IndexTab(
              child: children[i],
              isSelected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
            if (i < children.length - 1) const SizedBox(width: 4),
          ],
          if (children.isNotEmpty) const SizedBox(width: 6),
          _AddChildButton(
            accentColor: accentColor,
            enabled: canAddChild,
            onTap: onAddChild,
          ),
        ],
      ),
    );
  }
}

class _IndexTab extends StatelessWidget {
  const _IndexTab({
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  final ChildProfile child;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = child.themeColor;
    final height = isSelected ? _kSelectedTabHeight : _kUnselectedTabHeight;
    final bg = isSelected
        ? Colors.white
        : Colors.black.withValues(alpha: 0.05);
    final fg = isSelected
        ? Color.lerp(themeColor, Colors.black, 0.55)!
        : const Color(0xFF777777);
    final avatarRadius = isSelected ? 11.0 : 9.0;
    final iconSize = isSelected ? 13.0 : 11.0;
    final nameFontSize = isSelected ? 12.0 : 11.0;

    final Widget avatarWidget = child.photoBytes != null
        ? CircleAvatar(
            radius: avatarRadius,
            backgroundImage: MemoryImage(child.photoBytes!),
          )
        : CircleAvatar(
            radius: avatarRadius,
            backgroundColor: isSelected
                ? fg.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.35),
            child: Icon(
              kChildIconOptions[
                  child.iconIndex.clamp(0, kChildIconOptions.length - 1)],
              size: iconSize,
              color: fg,
            ),
          );

    final tabContent = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 12),
      constraints: BoxConstraints(minWidth: isSelected ? 96 : 84),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isSelected ? _kTabTopRadius : 12),
        ),
        border: isSelected
            ? Border(
                top: BorderSide(
                  color: themeColor.withValues(alpha: 0.20),
                  width: 0.5,
                ),
                left: BorderSide(
                  color: themeColor.withValues(alpha: 0.20),
                  width: 0.5,
                ),
                right: BorderSide(
                  color: themeColor.withValues(alpha: 0.20),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatarWidget,
          SizedBox(width: isSelected ? 6 : 5),
          Text(
            child.displayName,
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kTabTopRadius),
        ),
        child: isSelected
            ? Transform.translate(
                offset: const Offset(0, 1),
                child: tabContent,
              )
            : tabContent,
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({
    required this.accentColor,
    required this.enabled,
    required this.onTap,
  });

  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          Icons.add_rounded,
          size: 24,
          color: enabled ? accentColor : scheme.onSurfaceVariant,
        ),
        tooltip: 'お子様を追加',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
