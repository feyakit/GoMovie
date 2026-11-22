import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

class PhoneDestination {
  const PhoneDestination({required this.label, this.badge = 0});

  final String label;
  final int badge;
}

class PhoneNavigationBar extends StatelessWidget {
  const PhoneNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PhoneDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final go = GoColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (index, destination) in destinations.indexed)
                Expanded(
                  child: _Item(
                    destination: destination,
                    selected: index == selectedIndex,
                    brand: go.brand,
                    muted: colors.onSurfaceVariant,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destination,
    required this.selected,
    required this.brand,
    required this.muted,
    required this.onTap,
  });

  final PhoneDestination destination;
  final bool selected;
  final Color brand;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? brand : muted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        key: ValueKey('nav-${destination.label}'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: selected ? brand : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.enter,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(destination.label),
                ),
                if (destination.badge > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    destination.badge > 99 ? '99+' : '${destination.badge}',
                    style: TextStyle(
                      color: brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
