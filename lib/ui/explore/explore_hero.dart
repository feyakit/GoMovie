import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../app_scope.dart';
import '../shell/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_backdrop.dart';
import '../widgets/cover_image.dart';
import '../widgets/drama_grid.dart';
import '../widgets/focus_ring.dart';

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
    this.carousel = const [],
    this.onPlayItem,
    this.onDetailItem,
  });
  final Drama drama;
  final String kicker;
  final String meta;
  final String action;
  final VoidCallback onPlay;
  final VoidCallback onDetail;
  final double? progress;
  final List<Drama> carousel;
  final ValueChanged<Drama>? onPlayItem;
  final ValueChanged<Drama>? onDetailItem;

  _HeroMetrics _metrics(BuildContext context) =>
      switch (AppScope.formFactorOf(context)) {
        FormFactor.phone => (
          design: 358,
          height: 232,
          radius: 22,
          padding: const EdgeInsets.all(18),
          cover: const Size(124, 186),
          coverRadius: 14,
          gap: 18,
          width: null,
          title: 21,
          meta: 13,
          button: 42,
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
          height: 196,
          radius: 20,
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
    final buttonSize = Size(0, metrics.button);
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
              color: colors.primaryFixedDim,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
              stopIndicatorColor: Colors.transparent,
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              spacing: 12 * k,
              children: [
                FocusRing(
                  radius: 999,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFF2E54,
                          ).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      autofocus: television && ShellForeground.of(context),
                      onPressed: onPlay,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: buttonSize,
                        padding: EdgeInsets.fromLTRB(14 * k, 0, 20 * k, 0),
                        iconSize: 18 * k,
                        textStyle: TextStyle(
                          fontSize: metrics.meta,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(action),
                    ),
                  ),
                ),
                if (metrics.detail)
                  FocusRing(
                    radius: 999,
                    child: FilledButton(
                      onPressed: onDetail,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                        minimumSize: buttonSize,
                        padding: EdgeInsets.symmetric(horizontal: 20 * k),
                        textStyle: TextStyle(fontSize: metrics.meta),
                      ),
                      child: const Text('详情'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (AppScope.formFactorOf(context) == FormFactor.phone) {
      final items = carousel.isNotEmpty ? carousel : [drama];
      return _PhoneCarouselHero(
        items: items,
        kicker: kicker,
        fallbackMeta: meta,
        action: action,
        onPlay: onPlayItem ?? (_) => onPlay(),
        onDetail: onDetailItem ?? (_) => onDetail(),
      );
    }
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(metrics.radius),
      child: SizedBox(
        height: metrics.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: _shade.withValues(alpha: 0.92)),
            CoverBackdrop(
              drama: drama,
              sigma: 28,
              overlay: LinearGradient(
                stops: const [0, 0.55, 1],
                colors: [
                  _shade.withValues(alpha: 0.94),
                  _shade.withValues(alpha: 0.64),
                  _shade.withValues(alpha: 0.22),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: metrics.gap,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(metrics.coverRadius),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox.fromSize(
                      size: metrics.cover,
                      child: DramaCover(
                        drama: drama,
                        radius: metrics.coverRadius,
                        details: false,
                        exploreBlur: true,
                      ),
                    ),
                  ),
                  if (metrics.width case final width?)
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width),
                        child: info,
                      ),
                    )
                  else
                    Expanded(child: info),
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

class _PhoneCarouselHero extends StatefulWidget {
  const _PhoneCarouselHero({
    required this.items,
    required this.kicker,
    required this.fallbackMeta,
    required this.action,
    required this.onPlay,
    required this.onDetail,
  });

  final List<Drama> items;
  final String kicker;
  final String fallbackMeta;
  final String action;
  final ValueChanged<Drama> onPlay;
  final ValueChanged<Drama> onDetail;

  @override
  State<_PhoneCarouselHero> createState() => _PhoneCarouselHeroState();
}

class _PhoneCarouselHeroState extends State<_PhoneCarouselHero> {
  late final PageController _controller = PageController(
    viewportFraction: 0.56,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _metaFor(Drama drama) {
    final parts = [
      if (drama.category.isNotEmpty) drama.category,
      if (drama.episodes > 0) '共 ${drama.episodes} 集',
      if (drama.score.isNotEmpty) '★ ${drama.score}',
    ];
    return parts.isEmpty ? widget.fallbackMeta : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final currentIndex = _page.clamp(0, items.length - 1);
    final active = items[currentIndex];
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final screen = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final heroHeight =
        (screen.height * 0.34).clamp(248.0, 320.0) +
        math.max(0.0, (textScale - 1.0) * 34);
    return Semantics(
      container: true,
      label: widget.kicker,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: heroHeight,
              decoration: BoxDecoration(
                color: _shade,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: CoverBackdrop(
                      key: ValueKey(active.id),
                      drama: active,
                      sigma: 36,
                      opacity: 0.72,
                      overlay: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.55, 1],
                        colors: [
                          surface.withValues(alpha: 0.18),
                          _shade.withValues(alpha: 0.65),
                          _shade.withValues(alpha: 0.96),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 14),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          onPageChanged: (index) =>
                              setState(() => _page = index),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final page =
                                    _controller.hasClients &&
                                        _controller.position.haveDimensions
                                    ? (_controller.page ??
                                          currentIndex.toDouble())
                                    : currentIndex.toDouble();
                                final dist = (page - index).abs().clamp(
                                  0.0,
                                  1.0,
                                );
                                final scale = 1.0 - dist * 0.14;
                                final opacity = 1.0 - dist * 0.42;
                                return Center(
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: GestureDetector(
                                onTap: () => widget.onDetail(item),
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x80000000),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: DramaCover(
                                      drama: item,
                                      radius: 16,
                                      details: false,
                                      exploreBlur: true,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            Text(
                              active.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${widget.kicker} · ${_metaFor(active)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 6,
                            children: [
                              for (var i = 0; i < items.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: i == currentIndex ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: i == currentIndex
                                        ? AppTheme.brandGradient
                                        : null,
                                    color: i == currentIndex
                                        ? null
                                        : Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2E54).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: () => widget.onPlay(active),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(widget.action),
            ),
          ),
        ],
      ),
    );
  }
}
