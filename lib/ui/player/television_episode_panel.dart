import 'package:flutter/material.dart';

import '../../models.dart';
import '../theme/palette.dart';

class TelevisionEpisodeChoice {
  const TelevisionEpisodeChoice({
    required this.index,
    required this.route,
    required this.label,
    required this.number,
  });

  final int index;
  final String route;
  final String label;
  final int number;
}

List<TelevisionEpisodeChoice> televisionEpisodeChoices(List<Episode> episodes) {
  if (episodes.isEmpty) return const [];
  final parsed = <TelevisionEpisodeChoice>[];
  var routed = true;
  for (var i = 0; i < episodes.length; i++) {
    final episode = episodes[i];
    final sep = episode.title.indexOf(' · ');
    if (sep <= 0) {
      routed = false;
      break;
    }
    final route = episode.title.substring(0, sep).trim();
    final label = episode.title.substring(sep + 3).trim();
    if (route.isEmpty) {
      routed = false;
      break;
    }
    parsed.add(
      TelevisionEpisodeChoice(
        index: i,
        route: route,
        label: label.isEmpty ? '${episode.number}' : label,
        number: episode.number,
      ),
    );
  }
  if (!routed || parsed.map((item) => item.route).toSet().length < 2) {
    return [
      for (var i = 0; i < episodes.length; i++)
        TelevisionEpisodeChoice(
          index: i,
          route: '线路',
          label: '${episodes[i].number}',
          number: episodes[i].number,
        ),
    ];
  }
  return parsed;
}

class TelevisionEpisodePanel extends StatelessWidget {
  const TelevisionEpisodePanel({
    super.key,
    required this.choices,
    required this.route,
    required this.cursor,
    required this.onRoutes,
    required this.mismatched,
  });

  final List<TelevisionEpisodeChoice> choices;
  final String route;
  final int cursor;
  final bool onRoutes;
  final bool mismatched;

  @override
  Widget build(BuildContext context) {
    final go = GoColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final routes = <String>[];
    for (final choice in choices) {
      if (!routes.contains(choice.route)) routes.add(choice.route);
    }
    final visible = [
      for (final choice in choices)
        if (choice.route == route) choice,
    ];
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 36, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: go.surface,
            elevation: 0,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '线路与选集',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '焦点停在当前集。换线路不会自动开播，集数不一致时请确认后再播放。',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  if (routes.length > 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in routes)
                          _RouteChip(
                            label: name,
                            selected: name == route,
                            focused: onRoutes && name == route,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (index, choice) in visible.indexed)
                            _EpisodeCell(
                              label: choice.label,
                              selected: !onRoutes && index == cursor,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (mismatched) ...[
                    const SizedBox(height: 12),
                    Text(
                      '这条线路的集数和当前不一致，确认后才会播放你点中的集。',
                      style: TextStyle(
                        color: go.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.label,
    required this.selected,
    required this.focused,
  });

  final String label;
  final bool selected;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused || selected ? colors.onSurface : colors.outlineVariant,
          width: focused ? 3 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? colors.primary : colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 64,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? colors.onSurface : Colors.transparent,
          width: selected ? 3 : 0,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? colors.onPrimary : colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
