import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../app_scope.dart';
import '../shell/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_backdrop.dart';
import '../widgets/drama_grid.dart';
import '../widgets/play_orb.dart';

const _shade = Color(0xFF161214);

typedef _HeroMetrics = ({
  double design,
  double height,
  double radius,
  EdgeInsets padding,
  Size cover,
  double coverRadius,
  double gap,
  double? width,
  double title,
  double meta,
  double button,
  bool detail,
});

_HeroMetrics _scale(_HeroMetrics base, double k) => (
  design: base.design,
  height: base.height * k,
  radius: base.radius * k,
  padding: base.padding * k,
  cover: base.cover * k,
  coverRadius: base.coverRadius * k,
  gap: base.gap * k,
  width: switch (base.width) {
    final width? => width * k,
    null => null,
  },
  title: base.title * k,
  meta: base.meta * k,
  button: base.button * k,
  detail: base.detail,
);

class ExploreHero extends StatelessWidget {
  const ExploreHero({
    super.key,
    required this.drama,
    required this.kicker,
    required this.meta,
    required this.action,
    required this.onPlay,
    required this.onDetail,
    this.progress,
  });
  final Drama drama;
  final String kicker;
  final String meta;
  final String action;
  final VoidCallback onPlay;
  final VoidCallback onDetail;
  final double? progress;

  _HeroMetrics _metrics(BuildContext context) =>
      switch (AppScope.formFactorOf(context)) {
        FormFactor.phone => (
          design: 358,
          height: 228,
          radius: 22,
          padding: const EdgeInsets.all(16),
          cover: const Size(109, 164),
          coverRadius: 12,
          gap: 16,
          width: null,
          title: 20,
          meta: 13,
          button: 40,
          detail: false,
        ),
        FormFactor.window => (
          design: 1312,
          height: 232,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          cover: const Size(128, 192),
          coverRadius: 14,
          gap: 24,
          width: 520,
          title: 28,
          meta: 14,
          button: 40,
          detail: true,
        ),
        FormFactor.pad => (
          design: 914,
          height: 224,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          cover: const Size(123, 184),
          coverRadius: 14,
          gap: 24,
          width: 440,
          title: 26,
          meta: 14,
          button: 44,
          detail: true,
        ),
        FormFactor.television => (
          design: 844,
          height: 320,
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          cover: const Size(107, 160),
          coverRadius: 12,
          gap: 22,
          width: 420,
          title: 26,
          meta: 14,
          button: 40,
          detail: true,
        ),
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = _metrics(context);
      final k = math.max(
        1.0,
        dramaTileWidth(context, constraints.maxWidth) /
            dramaTileWidth(context, base.design),
      );
      return _hero(context, _scale(base, k), k);
    },
  );

  Widget _hero(BuildContext context, _HeroMetrics metrics, double k) {
    final colors = Theme.of(context).colorScheme;
    final television = AppScope.of(context).television;
    final muted = Colors.white.withValues(alpha: 0.78);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6 * k,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 3 * k),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6 * k,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 6 * k, height: 6 * k),
              ),
              Text(
                kicker,
                style: TextStyle(
                  fontSize: metrics.meta - 1.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
        Text(
          drama.title,
          maxLines: metrics.detail ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: metrics.title,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: Colors.white,
          ),
        ),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: metrics.meta, height: 1.3, color: muted),
        ),
        if (progress case final progress?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              color: colors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
              stopIndicatorColor: Colors.transparent,
            ),
          ),
      ],
    );
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(metrics.radius),
      child: SizedBox(
        height: metrics.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: _shade.withValues(alpha: 0.9)),
            CoverBackdrop(
              drama: drama,
              sigma: 40,
              overlay: LinearGradient(
                stops: metrics.detail ? const [0, 0.55, 1] : const [0, 1],
                colors: metrics.detail
                    ? [
                        _shade.withValues(alpha: 0.9),
                        _shade.withValues(alpha: 0.7),
                        _shade.withValues(alpha: 0.2),
                      ]
                    : [
                        _shade.withValues(alpha: 0.88),
                        _shade.withValues(alpha: 0.55),
                      ],
              ),
            ),
            if (!television)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onDetail),
                ),
              ),
            Padding(
              padding: metrics.padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: info),
                  PlayOrb(
                    onPressed: onPlay,
                    autofocus:
                        AppScope.of(context).television &&
                        ShellForeground.of(context),
                    size: metrics.button + 8,
                    tooltip: action,
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(metrics.radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(container: true, label: kicker, child: card);
  }
}
