import '../../drama_details.dart';
import '../../models.dart';

typedef RouteEntry = ({Episode episode, int index, String label});
typedef EpisodeRoute = ({String name, List<RouteEntry> entries});
typedef EpisodeScope = ({
  List<EpisodeRoute> routes,
  String routeName,
  List<RouteEntry> entries,
  int groupCount,
  int group,
});

final _numericTitlePattern = RegExp(r'^第?\s*\d{1,4}\s*集?$');

String compactEpisodeLabel(String rawLabel, int number) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty ||
      trimmed == '第$number集' ||
      _numericTitlePattern.hasMatch(trimmed)) {
    return '$number';
  }
  return trimmed;
}

List<EpisodeRoute> extractDetailRoutes(List<Episode> episodes) {
  if (episodes.isEmpty) return const [];
  final grouped = <String, List<RouteEntry>>{};
  for (var i = 0; i < episodes.length; i++) {
    final episode = episodes[i];
    final sep = episode.title.indexOf(' · ');
    if (sep <= 0) return const [];
    final route = episode.title.substring(0, sep).trim();
    final label = episode.title.substring(sep + 3).trim();
    if (route.isEmpty) return const [];
    (grouped[route] ??= []).add((
      episode: episode,
      index: i,
      label: label,
    ));
  }
  if (grouped.length < 2) return const [];
  return [
    for (final entry in grouped.entries)
      (name: entry.key, entries: entry.value),
  ];
}

EpisodeScope resolveDetailEpisodeScope(
  DramaDetails details, {
  required String routeDramaId,
  required String selectedRoute,
  required int routeGroup,
}) {
  final routes = extractDetailRoutes(details.episodes);
  if (routes.length < 2) {
    return (
      routes: const [],
      routeName: '',
      entries: [
        for (final (offset, episode) in details.groupEpisodes.indexed)
          (
            episode: episode,
            index: details.group * episodeGroupSize + offset,
            label: compactEpisodeLabel(episode.title, episode.number),
          ),
      ],
      groupCount: details.groupCount,
      group: details.group,
    );
  }
  var routeName = selectedRoute;
  var activeGroup = routeGroup;
  if (routeDramaId != details.drama.id ||
      !routes.any((route) => route.name == routeName)) {
    final current = details.currentIndex;
    final matched = current == null
        ? null
        : routes
              .where(
                (route) => route.entries.any((item) => item.index == current),
              )
              .firstOrNull;
    final chosen = matched ?? routes.first;
    routeName = chosen.name;
    if (current != null) {
      final pos = chosen.entries.indexWhere((item) => item.index == current);
      activeGroup = pos >= 0 ? pos ~/ episodeGroupSize : 0;
    } else {
      activeGroup = 0;
    }
  }
  final active = routes.firstWhere((route) => route.name == routeName);
  final groupCount = (active.entries.length / episodeGroupSize).ceil();
  final group = groupCount == 0 ? 0 : activeGroup.clamp(0, groupCount - 1);
  final slice = active.entries
      .skip(group * episodeGroupSize)
      .take(episodeGroupSize);
  return (
    routes: routes,
    routeName: active.name,
    entries: [
      for (final item in slice)
        (
          episode: item.episode,
          index: item.index,
          label: compactEpisodeLabel(item.label, item.episode.number),
        ),
    ],
    groupCount: groupCount,
    group: group,
  );
}
