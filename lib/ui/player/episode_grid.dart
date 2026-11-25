import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models.dart';
import '../detail/detail_routes.dart';
import '../theme/motion.dart';
import '../widgets/cover_image.dart';

const _cellHeight = 48.0;
const _descriptiveCellHeight = 52.0;
const _cellGap = 8.0;
const _listTop = 14.0;

class EpisodeGrid extends StatefulWidget {
  const EpisodeGrid({
    super.key,
    required this.episodes,
    required this.current,
    required this.selecting,
    required this.selected,
    required this.onSelectionChanged,
    required this.onPick,
    this.touch = false,
    this.header,
    this.downloaded = const {},
    this.downloading = const {},
    this.minCellWidth,
    this.inset = 16,
  });
  final List<Episode> episodes;
  final int current;
  final bool selecting;
  final Set<int> selected;
  final VoidCallback onSelectionChanged;
  final ValueChanged<int> onPick;
  final bool touch;
  final Widget? header;
  final Set<int> downloaded;
  final Set<int> downloading;
  final double? minCellWidth;
  final double inset;

  @override
  State<EpisodeGrid> createState() => _EpisodeGridState();
}

class _EpisodeGridState extends State<EpisodeGrid> {
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  final _routeBarKey = GlobalKey();
  bool? _dragAdds;
  int _dragAnchor = 0;
  Set<int> _dragBase = const {};
  Offset? _dragPoint;
  Timer? _autoScroll;
  double _gridWidth = 0;
  double _gridHeight = 0;
  int _columns = 5;
  double _activeCellHeight = _cellHeight;
  int _revealed = -1;
  String _selectedRoute = '';

  List<Episode> get _episodes => widget.episodes;
  Set<int> get _selected => widget.selected;
  bool _locked(int index) =>
      widget.downloaded.contains(index) || widget.downloading.contains(index);

  (List<EpisodeRoute>, String, List<RouteEntry>) _resolveEntries() {
    final routes = extractDetailRoutes(_episodes);
    if (routes.length < 2) {
      return (
        const [],
        '',
        [
          for (var i = 0; i < _episodes.length; i++)
            (
              episode: _episodes[i],
              index: i,
              label: compactEpisodeLabel(
                _episodes[i].title,
                _episodes[i].number,
              ),
            ),
        ],
      );
    }
    var routeName = _selectedRoute;
    if (!routes.any((r) => r.name == routeName)) {
      final matched = routes
          .where((r) => r.entries.any((e) => e.index == widget.current))
          .firstOrNull;
      routeName = (matched ?? routes.first).name;
    }
    final active = routes.firstWhere((r) => r.name == routeName);
    return (
      routes,
      active.name,
      [
        for (final item in active.entries)
          (
            episode: item.episode,
            index: item.index,
            label: compactEpisodeLabel(item.label, item.episode.number),
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(EpisodeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selecting) _dragEnd();
    if (!identical(oldWidget.episodes, widget.episodes)) {
      _selectedRoute = '';
    }
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  double get _top =>
      _listTop +
      (_headerKey.currentContext?.size?.height ?? 0) +
      (_routeBarKey.currentContext?.size?.height ?? 0);

  double get _rowExtent => _activeCellHeight + _cellGap;

  double get _cellWidth =>
      (_gridWidth - widget.inset * 2 - _cellGap * (_columns - 1)) / _columns;

  int? _hit(Offset point, {bool exact = false}) {
    final (_, _, entries) = _resolveEntries();
    if (entries.isEmpty || !_scroll.hasClients) return null;
    final pitch = _cellWidth + _cellGap;
    final x = point.dx - widget.inset;
    final y = point.dy + _scroll.offset - _top;
    if (exact &&
        (x < 0 ||
            y < 0 ||
            x >= pitch * _columns ||
            x % pitch > _cellWidth ||
            y % _rowExtent > _activeCellHeight)) {
      return null;
    }
    final rows = (entries.length / _columns).ceil();
    final column = (x / pitch).floor().clamp(0, _columns - 1);
    final row = (y / _rowExtent).floor().clamp(0, rows - 1);
    final pos = row * _columns + column;
    if (pos < entries.length) return entries[pos].index;
    return exact ? null : entries.last.index;
  }

  void _mark(int index) {
    final adds = _dragAdds;
    if (adds == null) return;
    final first = index < _dragAnchor ? index : _dragAnchor;
    final last = index < _dragAnchor ? _dragAnchor : index;
    final range = [
      for (var item = first; item <= last; item++)
        if (!_locked(item)) item,
    ];
    _selected
      ..clear()
      ..addAll(_dragBase);
    adds ? _selected.addAll(range) : _selected.removeAll(range);
    widget.onSelectionChanged();
  }

  void _toggle(int index) {
    if (_locked(index)) return;
    if (!_selected.remove(index)) _selected.add(index);
    widget.onSelectionChanged();
  }

  void _dragStart(Offset point) {
    final index = _hit(point, exact: true);
    if (index == null) return;
    _dragAdds = !_selected.contains(index);
    _dragAnchor = index;
    _dragBase = Set.of(_selected);
    _dragPoint = point;
    _mark(index);
  }

  void _dragMove(Offset point) {
    if (_dragAdds == null) return;
    _dragPoint = point;
    final index = _hit(point);
    if (index != null) _mark(index);
    if (_edgeSpeed(point.dy) != 0) {
      _autoScroll ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _autoScrollTick(),
      );
    }
  }

  void _dragEnd() {
    _dragAdds = null;
    _dragPoint = null;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  double _edgeSpeed(double y) {
    const zone = 64.0;
    final depth = y < zone
        ? y - zone
        : y > _gridHeight - zone
        ? y - (_gridHeight - zone)
        : 0.0;
    if (depth == 0) return 0;
    final t = (depth.abs() / zone).clamp(0.0, 2.0) / 2;
    return depth.sign * (120 + 1700 * t * t);
  }

  void _autoScrollTick() {
    final point = _dragPoint;
    final speed = point == null ? 0.0 : _edgeSpeed(point.dy);
    if (speed == 0 || !_scroll.hasClients) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    final position = _scroll.position;
    final next = (position.pixels + speed * .016).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _scroll.jumpTo(next);
    final index = _hit(point!);
    if (index != null) _mark(index);
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_scroll.hasClients || widget.current < 0) return;
    final (_, _, entries) = _resolveEntries();
    final pos = entries.indexWhere((e) => e.index == widget.current);
    if (pos < 0) return;
    final top = _top + pos ~/ _columns * _rowExtent;
    final position = _scroll.position;
    final view = position.viewportDimension;
    if (top >= position.pixels &&
        top + _activeCellHeight <= position.pixels + view) {
      return;
    }
    final target = (top - (view - _activeCellHeight) / 3).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      unawaited(
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _gridWidth = constraints.maxWidth;
      _gridHeight = constraints.maxHeight;
      final (routes, routeName, entries) = _resolveEntries();
      final descriptive = entries.any(
        (e) => e.label.length > 4 || RegExp(r'[^0-9]').hasMatch(e.label),
      );
      _activeCellHeight = descriptive ? _descriptiveCellHeight : _cellHeight;
      final effectiveMinWidth =
          widget.minCellWidth ?? (descriptive ? 148.0 : null);
      _columns = switch (effectiveMinWidth) {
        null => 5,
        final minimum => max(
          1,
          ((_gridWidth - widget.inset * 2 + _cellGap) / (minimum + _cellGap))
              .floor(),
        ),
      };
      if (_revealed != widget.current) {
        final animate = _revealed >= 0;
        _revealed = widget.current;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _reveal(animate: animate),
        );
      }
      final selecting = widget.selecting;
      final rows = SliverFixedExtentList(
        itemExtent: _rowExtent,
        delegate: SliverChildBuilderDelegate(
          childCount: (entries.length / _columns).ceil(),
          (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: _cellGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _cellGap,
              children: [
                for (
                  var pos = row * _columns;
                  pos < (row + 1) * _columns;
                  pos++
                )
                  Expanded(
                    child: pos < entries.length
                        ? () {
                            final item = entries[pos];
                            final index = item.index;
                            return _EpisodeCell(
                              episode: item.episode,
                              label: item.label,
                              descriptive: descriptive,
                              current: index == widget.current,
                              watched: index < widget.current,
                              selected: selecting
                                  ? _selected.contains(index)
                                  : null,
                              marker: widget.downloaded.contains(index)
                                  ? Icons.check_rounded
                                  : widget.downloading.contains(index)
                                  ? Icons.arrow_downward_rounded
                                  : null,
                              onPressed: _locked(index)
                                  ? null
                                  : !selecting
                                  ? () => widget.onPick(index)
                                  : widget.touch
                                  ? () => _toggle(index)
                                  : null,
                            );
                          }()
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      );
      final list = CustomScrollView(
        controller: _scroll,
        slivers: [
          if (widget.header case final header?)
            SliverToBoxAdapter(
              child: KeyedSubtree(key: _headerKey, child: header),
            ),
          if (routes.length > 1)
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _routeBarKey,
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(
                      widget.inset,
                      8,
                      widget.inset,
                      0,
                    ),
                    itemCount: routes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      final selected = route.name == routeName;
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(route.name),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _selectedRoute = route.name;
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              widget.inset,
              _listTop,
              widget.inset,
              8,
            ),
            sliver: rows,
          ),
        ],
      );
      if (widget.touch) {
        return GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: selecting
              ? (details) => _dragStart(details.localPosition)
              : null,
          onHorizontalDragUpdate: selecting
              ? (details) => _dragMove(details.localPosition)
              : null,
          onHorizontalDragEnd: selecting ? (_) => _dragEnd() : null,
          onHorizontalDragCancel: selecting ? _dragEnd : null,
          child: list,
        );
      }
      return Listener(
        onPointerDown: selecting
            ? (event) => _dragStart(event.localPosition)
            : null,
        onPointerMove: selecting
            ? (event) => _dragMove(event.localPosition)
            : null,
        onPointerUp: (_) => _dragEnd(),
        onPointerCancel: (_) => _dragEnd(),
        child: list,
      );
    },
  );
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    required this.episode,
    required this.label,
    required this.descriptive,
    required this.current,
    required this.watched,
    required this.selected,
    required this.onPressed,
    this.marker,
  });
  final Episode episode;
  final String label;
  final bool descriptive;
  final bool current;
  final bool watched;
  final bool? selected;
  final VoidCallback? onPressed;
  final IconData? marker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = current
        ? colors.onPrimaryContainer
        : watched || marker != null
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected ?? current,
      label:
          '$label${episode.vip ? '，VIP' : ''}'
          '${marker == null
              ? ''
              : marker == Icons.check_rounded
              ? '，已下载'
              : '，下载中'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.standard,
        decoration: ShapeDecoration(
          color: current
              ? colors.primaryContainer
              : marker != null
              ? colors.surfaceContainer
              : theme.brightness == Brightness.dark
              ? colors.surfaceContainerHigh
              : colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        foregroundDecoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected == true
                  ? colors.primary
                  : colors.primary.withValues(alpha: 0),
              width: 2,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: descriptive ? 10 : 4,
                      vertical: descriptive ? 4 : 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        if (current)
                          Icon(
                            Icons.equalizer_rounded,
                            size: 14,
                            color: foreground,
                          ),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: descriptive ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: descriptive ? 12.5 : 15,
                              height: descriptive ? 1.2 : 1.0,
                              fontWeight: current
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: foreground,
                              fontFeatures: descriptive
                                  ? null
                                  : const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (marker case final marker?)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Icon(marker, size: 13, color: foreground),
                  ),
                if (episode.vip)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: vipGold,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        child: Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 9,
                            height: 12 / 9,
                            fontWeight: FontWeight.w800,
                            color: onVipGold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
