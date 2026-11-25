import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/accent.dart';

/// 海报沉浸背景：封面放大模糊 → 主色衬色 → 底部渐隐到页面底色。
/// 规格见 docs/design/accent-plan.md §2。
class StageBackdrop extends StatelessWidget {
  const StageBackdrop({required this.cover, required this.accent, super.key});

  final String cover;
  final AccentScheme accent;

  static ImageProvider _provider(String cover) => ResizeImage.resizeIfNeeded(
    240,
    null,
    (cover.startsWith('http://') || cover.startsWith('https://'))
        ? NetworkImage(cover)
        : FileImage(File(cover)),
  );

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover.isNotEmpty)
            RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image(
                  image: _provider(cover),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                  frameBuilder: (context, child, frame, wasSync) => Opacity(
                    opacity: (frame == null && !wasSync) ? 0 : 1,
                    child: child,
                  ),
                ),
              ),
            ),
          ColoredBox(color: accent.veil),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: 0.34),
                  base.withValues(alpha: 0.66),
                  base,
                ],
                stops: const [0, 0.46, 0.80],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 把页面包成「取色主题 + 沉浸背景」。
/// 页面自己的 Scaffold 背景会被置透明，背景层才透得出来。
class AccentStage extends StatelessWidget {
  const AccentStage({
    required this.accent,
    required this.cover,
    required this.child,
    super.key,
  });

  final AccentScheme accent;
  final String cover;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final themed = base.copyWith(
      colorScheme: accent.applyTo(base.colorScheme),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
    );
    return AnimatedTheme(
      data: themed,
      duration: const Duration(milliseconds: 320),
      curve: const Cubic(0.22, 0.9, 0.28, 1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          StageBackdrop(cover: cover, accent: accent),
          child,
        ],
      ),
    );
  }
}
