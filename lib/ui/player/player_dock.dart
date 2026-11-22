import 'package:flutter/material.dart';

import '../theme/palette.dart';

class PlayerDock extends StatelessWidget {
  const PlayerDock({
    super.key,
    required this.speedLabel,
    required this.onLock,
    required this.onRoutes,
    required this.onEpisodes,
    required this.onSpeed,
    this.danmakuSupported = false,
    this.danmakuEnabled = false,
    this.onDanmaku,
  });

  final String speedLabel;
  final VoidCallback? onLock;
  final VoidCallback? onDanmaku;
  final VoidCallback? onRoutes;
  final VoidCallback? onEpisodes;
  final VoidCallback? onSpeed;
  final bool danmakuSupported;
  final bool danmakuEnabled;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _Pill(label: '锁屏', icon: Icons.lock_open_rounded, onPressed: onLock),
        if (danmakuSupported)
          _Pill(
            label: danmakuEnabled ? '弹幕开' : '弹幕',
            icon: danmakuEnabled
                ? Icons.subtitles_rounded
                : Icons.subtitles_off_rounded,
            selected: danmakuEnabled,
            onPressed: onDanmaku,
          ),
        _Pill(label: '换源', icon: Icons.alt_route_rounded, onPressed: onRoutes),
        _Pill(
          label: '选集',
          icon: Icons.view_list_rounded,
          onPressed: onEpisodes,
        ),
        _Pill(label: speedLabel, icon: Icons.speed_rounded, onPressed: onSpeed),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brand = GoColors.of(context).brand;
    final foreground = selected ? brand : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white.withValues(alpha: selected ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
