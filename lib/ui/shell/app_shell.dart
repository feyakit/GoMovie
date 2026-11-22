import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../download_converter.dart';
import '../../merge_queue.dart';
import '../../download_overview.dart';
import '../../follow_updater.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../explore/explore_page.dart';
import '../library/library_page.dart';
import '../mine/mine_page.dart';
import '../search/search_page.dart';
import '../update_prompt.dart';
import '../modules/module_install.dart';
import '../widgets/bar_button.dart';
import '../theme/motion.dart';
import '../widgets/brand_mark.dart';
import '../widgets/focus_ring.dart';
import '../widgets/motion/motion_widgets.dart';
import '../widgets/phone_navigation_bar.dart';

enum AppTab {
  explore('发现', Icons.explore_outlined, Icons.explore),
  search('搜索', Icons.search_rounded, Icons.search),
  library('片库', Icons.video_library_outlined, Icons.video_library_rounded),
  manage('管理', Icons.tune_rounded, Icons.tune);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

Future<T?> openPage<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: switch (AppScope.formFactorOf(context)) {
        FormFactor.phone || FormFactor.television => true,
        FormFactor.pad || FormFactor.window => false,
      },
    ).push(MaterialPageRoute<T>(builder: builder));

class ShellForeground extends InheritedWidget {
  const ShellForeground({
    super.key,
    required this.foreground,
    required super.child,
  });
  final bool foreground;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShellForeground>()
          ?.foreground ??
      true;

  @override
  bool updateShouldNotify(ShellForeground oldWidget) =>
      foreground != oldWidget.foreground;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final LocalStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _heroes = [
    for (final _ in AppTab.values) MaterialApp.createMaterialHeroController(),
  ];
  final _navigators = [
    for (final _ in AppTab.values) GlobalKey<NavigatorState>(),
  ];
  final _tabFocus = [for (final _ in AppTab.values) FocusNode()];
  final _tabScrolls = [for (final _ in AppTab.values) ScrollController()];
  final _libraryEntry = FocusNode();
  final _manageEntry = FocusNode();
  final _rail = FocusNode();
  final _explore = GlobalKey<ExplorePageState>();
  var _tab = AppTab.explore;
  var _railFocused = false;
  FocusNode? _lastFocus;
  Timer? _exitWindow;
  DownloadOverview? _downloads;
  DownloadConverter? _converter;
  MergeQueue? _merges;
  FollowUpdater? _followUpdater;

  NavigatorState? get _navigator => _navigators[_tab.index].currentState;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_followFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(offerRestoredModules(context, widget.store));
      runStartupChecks(context, widget.store);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _downloads ??= DownloadOverview(
      AppScope.of(context).repository,
      widget.store,
    );
    _converter ??= DownloadConverter(
      AppScope.of(context).repository,
      _downloads!,
    );
    _merges ??= MergeQueue(AppScope.of(context).repository)
      ..onFinished = _mergeFinished;
    _followUpdater ??= FollowUpdater(
      AppScope.of(context).repository,
      widget.store,
    )..start();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_followFocus);
    for (final node in _tabFocus) {
      node.dispose();
    }
    for (final scroll in _tabScrolls) {
      scroll.dispose();
    }
    for (final hero in _heroes) {
      hero.dispose();
    }
    _libraryEntry.dispose();
    _manageEntry.dispose();
    _rail.dispose();
    _exitWindow?.cancel();
    _converter?.dispose();
    _merges?.dispose();
    _downloads?.dispose();
    _followUpdater?.dispose();
    super.dispose();
  }

  List<AppTab> get _tabs => AppTab.values;

  void _select(AppTab tab) => setState(() => _tab = tab);

  void _tap(AppTab tab) {
    if (tab != _tab) return _select(tab);
    final navigator = _navigator;
    if (navigator != null && navigator.canPop()) {
      return navigator.popUntil((route) => route.isFirst);
    }
    if (tab == AppTab.explore) return _explore.currentState?.reselect();
    for (final position in _tabScrolls[tab.index].positions) {
      if (position.pixels <= position.minScrollExtent) continue;
      unawaited(
        position.animateTo(
          position.minScrollExtent,
          duration: Motion.of(context, Motion.long),
          curve: Motion.enter,
        ),
      );
    }
  }

  void _mergeFinished(MergeTask task) {
    if (task.state == MergeState.cancelled) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          task.state == MergeState.done
              ? '「${task.fileName}」${task.message}'
              : '「${task.fileName}」合并失败：${task.message}',
        ),
      ),
    );
  }

  void _followFocus() {
    final previous = _lastFocus;
    final focused = _lastFocus = FocusManager.instance.primaryFocus;
    final index = _tabFocus.indexWhere((node) => node == focused);
    if (index < 0) return;
    if (previous?.ancestors.contains(_rail) ?? false) {
      _select(AppTab.values[index]);
    } else if (index != _tab.index) {
      _tabFocus[_tab.index].requestFocus();
    }
  }

  Future<void> _back() async {
    final navigator = _navigator;
    if (navigator != null && await navigator.maybePop()) return;
    if (!mounted) return;
    final television = AppScope.of(context).television;
    if (television) {
      if (!_railFocused) {
        _tabFocus[_tab.index].requestFocus();
        return;
      }
      _armExit();
      return;
    }
    if (_tab == AppTab.explore) {
      _armExit();
      return;
    }
    _select(AppTab.explore);
  }

  void _armExit() {
    const window = Duration(seconds: 2);
    setState(() {
      _exitWindow = Timer(window, () {
        if (mounted) setState(() => _exitWindow = null);
      });
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('再按一次返回退出应用'), duration: window),
      );
  }

  Widget _root(AppTab tab) => switch (tab) {
    AppTab.explore => ExplorePage(key: _explore, store: widget.store),
    AppTab.search => SearchPage(
      store: widget.store,
      source: SourceSite.byId(widget.store.source),
      aggregate: true,
      embedded: true,
    ),
    AppTab.library => LibraryPage(
      store: widget.store,
      downloads: _downloads!,
      converter: _converter!,
      merges: _merges!,
      entryFocus: _libraryEntry,
      onExitUp: _tabFocus[AppTab.library.index].requestFocus,
    ),
    AppTab.manage => MinePage(
      store: widget.store,
      entryFocus: _manageEntry,
      onExitUp: _tabFocus[AppTab.manage.index].requestFocus,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final stack = NotificationListener<NavigationNotification>(
      onNotification: (_) {
        setState(() {});
        return false;
      },
      child: IndexedStack(
        index: _tab.index,
        children: [
          for (final tab in AppTab.values)
            _TabFade(
              selected: tab == _tab,
              child: HeroControllerScope(
                controller: _heroes[tab.index],
                child: Navigator(
                  key: _navigators[tab.index],
                  routeTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
                  routeDirectionalTraversalEdgeBehavior:
                      TraversalEdgeBehavior.parentScope,
                  onGenerateInitialRoutes: (_, _) => [
                    MaterialPageRoute<void>(
                      builder: (_) => PrimaryScrollController(
                        controller: _tabScrolls[tab.index],
                        child: _root(tab),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    final pages = ShellForeground(
      foreground: ModalRoute.of(context)?.isCurrent ?? true,
      child: stack,
    );
    final television = AppScope.of(context).television;
    final tabs = _tabs;
    if (!tabs.contains(_tab)) _tab = AppTab.explore;
    final covered = _navigator?.canPop() ?? false;
    return PopScope(
      canPop:
          _exitWindow != null &&
          !covered &&
          (television ? _railFocused : _tab == AppTab.explore),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: switch (AppScope.formFactorOf(context)) {
        FormFactor.phone => Scaffold(
          body: pages,
          bottomNavigationBar: covered
              ? null
              : PhoneNavigationBar(
                  destinations: [
                    for (final tab in tabs)
                      PhoneDestination(
                        label: tab.label,
                        badge: tab == AppTab.manage
                            ? (_downloads?.active ?? 0)
                            : 0,
                      ),
                  ],
                  selectedIndex: tabs.indexOf(_tab),
                  onSelected: (index) => _tap(tabs[index]),
                ),
        ),
        FormFactor.pad || FormFactor.window => _wide(pages),
        FormFactor.television => Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (!covered) _televisionRail(),
                Expanded(child: pages),
              ],
            ),
          ),
        ),
      },
    );
  }

  Widget _badged(AppTab tab, Widget icon) => tab == AppTab.manage
      ? _DownloadBadge(downloads: _downloads!, child: icon)
      : icon;

  Widget _televisionRail() {
    final colors = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _rail,
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _railFocused = focused),
      onKeyEvent: (_, event) {
        final entry = switch (_tab) {
          AppTab.library => _libraryEntry,
          AppTab.manage => _manageEntry,
          AppTab.explore || AppTab.search => null,
        };
        if (event is KeyUpEvent ||
            event.logicalKey != LogicalKeyboardKey.arrowRight ||
            entry?.context == null) {
          return KeyEventResult.ignored;
        }
        revealFocus(entry!);
        return KeyEventResult.handled;
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
            child: Column(
              children: [
                const BrandMark(size: 44),
                const SizedBox(height: 22),
                for (final tab in _tabs)
                  _TelevisionTab(
                    tab: tab,
                    selected: tab == _tab,
                    focusNode: _tabFocus[tab.index],
                    onTap: () => _select(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wide(Widget pages) {
    final roomy = MediaQuery.sizeOf(context).width >= 840;
    final expanded = roomy && widget.store.sideBarExpanded;
    return Scaffold(
      body: Row(
        children: [
          _SideBar(
            tabs: _tabs,
            selected: _tab,
            expanded: expanded,
            badged: _badged,
            onSelect: _tap,
            onToggle: roomy
                ? () => widget.store.setSideBarExpanded(!expanded)
                : null,
          ),
          Expanded(
            child: RepaintBoundary(
              child: Builder(
                builder: (body) => MediaQuery.removePadding(
                  context: body,
                  removeLeft: true,
                  child: pages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SideMetrics = ({
  double width,
  double inset,
  double top,
  double menuGap,
  double spacing,
  double itemHeight,
  double iconSize,
  double labelSize,
  EdgeInsets labelPadding,
});

_SideMetrics _sideMetrics({required bool desktop, required bool expanded}) =>
    desktop
    ? (
        width: expanded ? 240 : 80,
        inset: 12,
        top: 12,
        menuGap: 8,
        spacing: 4,
        itemHeight: 48,
        iconSize: 22,
        labelSize: 14,
        labelPadding: const EdgeInsets.fromLTRB(17, 0, 16, 0),
      )
    : (
        width: expanded ? 232 : 88,
        inset: 16,
        top: 8,
        menuGap: 12,
        spacing: 4,
        itemHeight: 56,
        iconSize: 24,
        labelSize: 15,
        labelPadding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
      );

class _TabFade extends StatelessWidget {
  const _TabFade({required this.selected, required this.child});
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: selected ? 1 : 0,
    duration: selected ? Motion.of(context, Motion.medium) : Duration.zero,
    curve: Motion.enter,
    child: child,
  );
}

class _SideBar extends StatefulWidget {
  const _SideBar({
    required this.tabs,
    required this.selected,
    required this.expanded,
    required this.badged,
    required this.onSelect,
    this.onToggle,
  });
  final List<AppTab> tabs;
  final AppTab selected;
  final bool expanded;
  final Widget Function(AppTab tab, Widget icon) badged;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback? onToggle;

  @override
  State<_SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<_SideBar> {
  bool? _desktop;
  bool _roomy = false;

  @override
  Widget build(BuildContext context) {
    final desktop = AppScope.formFactorOf(context) == FormFactor.window;
    final roomy = widget.onToggle != null;
    final animate = _desktop == desktop && _roomy == roomy;
    _desktop = desktop;
    _roomy = roomy;
    final expanded = widget.expanded;
    final onToggle = widget.onToggle;
    final metrics = _sideMetrics(desktop: desktop, expanded: expanded);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: AnimatedContainer(
          key: const ValueKey('side-bar'),
          duration: animate
              ? Motion.of(context, expanded ? Motion.long : Motion.medium)
              : Duration.zero,
          curve: expanded ? Motion.enter : Motion.exit,
          width: metrics.width,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.inset,
              metrics.top,
              metrics.inset,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: metrics.spacing,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: metrics.menuGap),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 48,
                            child: onToggle == null
                                ? null
                                : Center(
                                    child: BarButton(
                                      icon: Icons.menu_rounded,
                                      tooltip: expanded ? '收起侧栏' : '展开侧栏',
                                      onPressed: onToggle,
                                    ),
                                  ),
                          ),
                          if (constraints.maxWidth >= 148)
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: expanded ? 1 : 0,
                                duration: Motion.of(context, Motion.short),
                                curve: expanded
                                    ? const Interval(
                                        0.35,
                                        1,
                                        curve: Motion.enter,
                                      )
                                    : Motion.exit,
                                child: const BrandLockup(
                                  markSize: 28,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final tab in widget.tabs)
                  _SideItem(
                    tab: tab,
                    selected: tab == widget.selected,
                    expanded: expanded,
                    metrics: metrics,
                    badged: widget.badged,
                    onTap: () => widget.onSelect(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.tab,
    required this.selected,
    required this.expanded,
    required this.metrics,
    required this.badged,
    required this.onTap,
  });
  final AppTab tab;
  final bool selected;
  final bool expanded;
  final _SideMetrics metrics;
  final Widget Function(AppTab tab, Widget icon) badged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconColor = selected ? colors.primary : colors.onSurfaceVariant;
    final labelColor = selected ? colors.onSurface : colors.onSurfaceVariant;
    final icon = badged(
      tab,
      ToggleIconSwitcher(
        child: Icon(
          selected ? tab.selectedIcon : tab.icon,
          key: ValueKey(selected),
          color: iconColor,
          size: metrics.iconSize,
        ),
      ),
    );
    final duration = Motion.of(context, Motion.medium);
    final item = AnimatedContainer(
      duration: duration,
      curve: Motion.standard,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('nav-${tab.name}'),
          onTap: onTap,
          child: SizedBox(
            height: metrics.itemHeight,
            child: Stack(
              children: [
                if (selected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const SizedBox(width: 3.5, height: 18),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(left: metrics.labelPadding.left),
                  child: Center(
                    child: Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: ExcludeSemantics(
                            excluding: !expanded,
                            child: AnimatedOpacity(
                              opacity: expanded ? 1 : 0,
                              alwaysIncludeSemantics: true,
                              duration: Motion.of(context, Motion.short),
                              curve: expanded
                                  ? const Interval(0.4, 1, curve: Motion.enter)
                                  : Motion.exit,
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                curve: Motion.standard,
                                style: theme.textTheme.titleSmall!.copyWith(
                                  fontSize: metrics.labelSize,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: labelColor,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: metrics.labelPadding.right,
                                  ),
                                  child: Text(
                                    tab.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      child: FocusRing(
        radius: metrics.itemHeight / 2,
        child: expanded ? item : Tooltip(message: tab.label, child: item),
      ),
    );
  }
}

class _DownloadBadge extends StatelessWidget {
  const _DownloadBadge({required this.downloads, required this.child});
  final DownloadOverview downloads;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: downloads,
    builder: (context, child) {
      final count = downloads.active;
      return Badge(
        isLabelVisible: count > 0,
        label: ToggleIconSwitcher(
          child: Text(
            count > 99 ? '99+' : '$count',
            key: ValueKey(count > 99 ? 100 : count),
          ),
        ),
        child: child,
      );
    },
    child: child,
  );
}

class _TelevisionTab extends StatelessWidget {
  const _TelevisionTab({
    required this.tab,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });
  final AppTab tab;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => Semantics(
        selected: selected,
        label: tab.label,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('nav-${tab.name}'),
              focusNode: focusNode,
              autofocus: tab == AppTab.explore,
              focusColor: Colors.transparent,
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: FocusOutline(
                visible: focusVisible(focusNode.hasFocus),
                radius: 12,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 3,
                        height: selected ? 22 : 0,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
