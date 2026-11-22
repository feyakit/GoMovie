import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 主播放键是唯一允许使用折面渐变的控件。
class PlayOrb extends StatelessWidget {
  const PlayOrb({
    super.key,
    required this.onPressed,
    this.size = 52,
    this.autofocus = false,
    this.tooltip = '播放',
  });

  final VoidCallback? onPressed;
  final double size;
  final bool autofocus;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: IconButton(
      tooltip: tooltip,
      autofocus: autofocus,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: Size(size, size),
        fixedSize: Size(size, size),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.transparent,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: onPressed == null ? null : AppTheme.brandGradient,
          color: onPressed == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.crimson.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Icon(Icons.play_arrow_rounded, size: size * 0.56),
      ),
    ),
  );
}
