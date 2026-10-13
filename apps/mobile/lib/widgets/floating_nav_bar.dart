import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// The floating pill tab bar: hovers above the content with a soft green
/// shadow; the active tab grows into a deep-green capsule with its label,
/// the rest stay as quiet icons. The capsule slides between tabs.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Palette.lineSoft),
        boxShadow: Shadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavButton(
              item: items[i],
              active: i == index,
              onTap: () {
                if (i != index) HapticFeedback.selectionClick();
                onTap(i);
              },
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: active ? 18 : 15),
          decoration: BoxDecoration(
            color: active ? Palette.greenDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(
                      active ? item.activeIcon : item.icon,
                      key: ValueKey(active),
                      size: 23,
                      color: active ? Palette.gold : Palette.inkSoft,
                    ),
                  ),
                  if (item.badge > 0)
                    Positioned(
                      right: -7,
                      top: -5,
                      child: _Badge(count: item.badge, onDark: active),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Palette.bg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.1,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.onDark});

  final int count;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Palette.terracotta,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: onDark ? Palette.greenDeep : Palette.card, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Palette.card, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}
