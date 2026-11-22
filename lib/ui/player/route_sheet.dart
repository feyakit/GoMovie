import 'dart:async';

import 'package:flutter/material.dart';

import '../../playback_session.dart';
import '../theme/palette.dart';
import 'playback_sheets.dart';
import 'television_episode_panel.dart';

Future<void> showRouteSheet(BuildContext context, PlaybackSession session) {
  return showPlayerSheet(
    context,
    (_) => _RouteSheet(session: session),
    fitContent: true,
  );
}

class _RouteSheet extends StatefulWidget {
  const _RouteSheet({required this.session});

  final PlaybackSession session;

  @override
  State<_RouteSheet> createState() => _RouteSheetState();
}

class _RouteSheetState extends State<_RouteSheet> {
  late String _route;

  @override
  void initState() {
    super.initState();
    final choices = televisionEpisodeChoices(widget.session.detail.episodes);
    final current = choices
        .where((choice) => choice.index == widget.session.index)
        .firstOrNull;
    _route = current?.route ?? (choices.isEmpty ? '' : choices.first.route);
  }

  @override
  Widget build(BuildContext context) {
    final choices = televisionEpisodeChoices(widget.session.detail.episodes);
    final routes = <String>[];
    for (final choice in choices) {
      if (!routes.contains(choice.route)) routes.add(choice.route);
    }
    final counts = <String, int>{};
    for (final choice in choices) {
      counts[choice.route] = (counts[choice.route] ?? 0) + 1;
    }
    final mismatched = counts.values.toSet().length > 1;
    final visible = [
      for (final choice in choices)
        if (choice.route == _route) choice,
    ];
    final colors = Theme.of(context).colorScheme;
    final go = GoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(
          children: [Expanded(child: Text('线路与选集', style: sheetTitle))],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            mismatched
                ? '各线路集数不一致。点某一集才会播放，不会自动跳到可能错误的集。'
                : '同一剧的线路可以切换。点某一集才会开始播放。',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
        ),
        if (routes.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final name in routes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$name (${counts[name]})'),
                      selected: name == _route,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _route = name),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 84,
              mainAxisExtent: 48,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final choice = visible[index];
              final selected = choice.index == widget.session.index;
              return Material(
                color: selected ? go.brand : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (choice.index != widget.session.index) {
                      unawaited(widget.session.play(choice.index));
                    }
                  },
                  child: Center(
                    child: Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
