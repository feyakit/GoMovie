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

bool isDescriptiveEpisodeLabel(String rawLabel, int number) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty ||
      trimmed == '$number' ||
      trimmed == '第$number集' ||
      _numericTitlePattern.hasMatch(trimmed)) {
    return false;
  }
  return true;
}

String compactEpisodeLabel(String rawLabel, int number) =>
    isDescriptiveEpisodeLabel(rawLabel, number) ? rawLabel.trim() : '$number';

bool isNetdiskEpisode(Episode episode) {
  final videoUrl = (episode.raw['videoUrl'] as String? ?? '').trim();
  final source = (episode.raw['source'] as String? ?? '').trim();
  return videoUrl.startsWith('netdisk:') || source == 'quark' || source == 'uc';
}

List<EpisodeRoute> extractDetailRoutes(List<Episode> episodes) {
  if (episodes.isEmpty) return const [];
  var hasRoutePrefix = false;
  for (final episode in episodes) {
    final sep = episode.title.indexOf(' · ');
    if (sep > 0 && episode.title.substring(0, sep).trim().isNotEmpty) {
      hasRoutePrefix = true;
      break;
    }
  }
  if (!hasRoutePrefix) return const [];
  final grouped = <String, List<RouteEntry>>{};
  for (var i = 0; i < episodes.length; i++) {
    final episode = episodes[i];
    final sep = episode.title.indexOf(' · ');
    if (sep > 0) {
      final route = episode.title.substring(0, sep).trim();
      final label = episode.title.substring(sep + 3).trim();
      if (route.isNotEmpty) {
        (grouped[route] ??= []).add((episode: episode, index: i, label: label));
        continue;
      }
    }
    (grouped['默认线路'] ??= []).add((
      episode: episode,
      index: i,
      label: episode.title.trim(),
    ));
  }
  if (grouped.isEmpty) return const [];
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
  if (routes.isEmpty) {
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
