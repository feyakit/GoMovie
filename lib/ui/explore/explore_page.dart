import 'dart:async';

import 'package:flutter/material.dart';

import '../../drama_feed.dart';
import '../../explore_feed.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../../webview_bridge.dart';
import '../app_scope.dart';
import '../cover_blur.dart';
import '../detail/detail_page.dart';
import '../settings/settings_page.dart';
import '../settings/sorani_account_view.dart';
import '../shell/app_shell.dart';
import '../theme/motion.dart';
import '../widgets/bar_button.dart';
import '../widgets/category_tabs.dart';
import '../widgets/choice_panel.dart';
import '../widgets/drama_grid.dart';
import '../widgets/follow_button.dart';
import '../widgets/motion/motion_widgets.dart';
import '../widgets/page_header.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/source_bar.dart';
import '../widgets/status_view.dart';
import '../widgets/swipe_switch.dart';
import 'explore_hero.dart';
import 'source_actions.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.store});
  final LocalStore store;

  @override
  State<ExplorePage> createState() => ExplorePageState();
}

class ExplorePageState extends State<ExplorePage> {
  ExploreFeed? _explore;
  bool _filtersOpen = false;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _tabsKey = GlobalKey();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  String _shown = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _explore ??= ExploreFeed(AppScope.of(context).repository, widget.store);
  }

  @override
  void dispose() {
    _explore?.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _explore?.refresh();
  }

  void reselect() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset <= 0) {
      unawaited(_refreshKey.currentState?.show());
      return;
    }
    unawaited(
      _scroll.animateTo(
        0,
        duration: Motion.of(context, Motion.long),
        curve: Motion.enter,
      ),
    );
  }

  void _selectTab(String id) {
    final explore = _explore!;
    if (id != explore.tab.id) {
      explore.select(id);
      if (explore.hasFilters && !_filtersOpen) {
        setState(() => _filtersOpen = true);
      }
      return;
    }
    if (explore.hasFilters) {
      setState(() => _filtersOpen = !_filtersOpen);
    }
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    unawaited(
      _scroll.animateTo(
        0,
        duration: Motion.of(context, Motion.long),
        curve: Motion.enter,
      ),
    );
  }

  void _open(Drama drama, {bool autoplay = false}) => openPage<void>(
    context,
    (_) => DetailPage(store: widget.store, drama: drama, autoplay: autoplay),
  );

  Future<void> _openNetdiskShare() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('粘贴网盘链接'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://pan.quark.cn/s/...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('解析'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || url == null || url.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在解析网盘分享...'),
        duration: Duration(seconds: 15),
      ),
    );
    try {
      final drama = await AppScope.of(context).repository.netdiskOpenShare(url);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      _open(drama);
    } catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  /// 筛选 chip 的文案：没选就显示分组名，选了显示「分组: 值」。
  String _filterLabel(ExploreFeed explore, CatalogFilter filter) {
    final value = explore.filterValue(filter.key);
    if (value.isEmpty) return filter.name;
    for (final item in filter.values) {
      if (item.value == value) return '${filter.name}: ${item.name}';
    }
    return '${filter.name}: $value';
  }

  Future<void> _pickFilter(ExploreFeed explore, String key) async {
    CatalogFilter? filter;
    for (final item in explore.filters) {
      if (item.key == key) {
        filter = item;
        break;
      }
    }
    if (filter == null) return;
    final value = await showChoicePanel<String>(
      context: context,
      title: filter.name,
      options: [
        const ChoiceOption('', '不限'),
        for (final item in filter.values) ChoiceOption(item.value, item.name),
      ],
      selected: explore.filterValue(key),
      grid: ChoiceGrid.categories,
    );
    if (value != null) explore.setFilter(key, value);
  }

  Future<void> _pickCategory(BuildContext anchor) async {
    final explore = _explore!;
    final value = await showChoicePanel<String>(
      context: anchor,
      title: '全部分类',
      options: [for (final tab in explore.tabs) ChoiceOption(tab.id, tab.name)],
      selected: explore.tab.id,
      grid: ChoiceGrid.categories,
    );
    if (value != null) explore.select(value);
  }

  void _searchSubmitted(SourceSite source, String query) {
    if (query.trim().isEmpty) return;
    _search.clear();
    openSearch(context, widget.store, source, query: query);
  }

  void _resetScroll(ExploreFeed explore, {required bool deferred}) {
    final source = '${explore.source?.id}|';
    final shown = '$source${explore.tab.id}';
    if (shown == _shown) return;
    final switched = _shown.startsWith(source);
    _shown = shown;
    if (deferred && switched) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _toTop());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_explore!, widget.store]),
    builder: (context, _) {
      final explore = _explore!;
      final source = explore.source;
      final form = AppScope.formFactorOf(context);
      final television = form == FormFactor.television;
      final desktop = form == FormFactor.window;
      _resetScroll(explore, deferred: _swipes(form));
      if (source == null) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!television) const PageHeader(title: '发现'),
                Expanded(
                  child: SourceSite.values.isEmpty
                      ? StatusView(
                          title: '还没有安装站源',
                          message: widget.store.profile.admin
                              ? '站源以模块的形式提供，请在 我的 › 模块 安装。'
                              : '请联系管理员安装站源模块。',
                          icon: Icons.extension_off_rounded,
                        )
                      : const StatusView(
                          title: '暂无可用站源',
                          message: '请在 我的 › 模块 中开启站源，或联系管理员开放权限。',
                          icon: Icons.public_off_rounded,
                        ),
                ),
              ],
            ),
          ),
        );
      }
      final inset = switch (form) {
        FormFactor.phone => 16.0,
        FormFactor.pad || FormFactor.window => 24.0,
        FormFactor.television => televisionInset,
      };
      final tabs = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: form == FormFactor.phone ? 0 : inset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryTabs<String>(
              key: _tabsKey,
              options: [
                for (final tab in explore.tabs) ChoiceOption(tab.id, tab.name),
              ],
              selected: explore.tab.id,
              onSelected: _selectTab,
              onShowAll: _pickCategory,
            ),
            // 二级筛选（TVBox 订阅源才有）：点击分类选项卡后再展开
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.standard,
              child: explore.hasFilters && _filtersOpen
                  ? CategoryTabs<String>(
                      options: [
                        for (final filter in explore.filters)
                          ChoiceOption(
                            filter.key,
                            _filterLabel(explore, filter),
                          ),
                      ],
                      selected: '',
                      onSelected: (key) => _pickFilter(explore, key),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (!television)
                SourceBar(
                  source: source.name,
                  searchController: _search,
                  recentSearches: widget.store.recentSearches,
                  onForgetSearch: (query) => widget.store
                      .forgetSearch(query)
                      .catchError((Object _) {}),
                  onSwitchSource: (anchor) => pickSource(anchor, widget.store),
                  onOpenSearch: () => openSearch(context, widget.store, source),
                  onSearchSubmitted: (query) => _searchSubmitted(source, query),
                  leading: [
                    if (widget.store.blurCoversButton)
                      if (CoverBlurScope.of(context) case final blur?)
                        BarButton(
                          icon: blur.mode != CoverBlur.off
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          tooltip: blur.mode != CoverBlur.off ? '显示封面' : '模糊封面',
                          onPressed: blur.onToggle,
                        ),
                  ],
                  actions: [
                    BarButton(
                      icon: Icons.link_rounded,
                      tooltip: '粘贴网盘链接',
                      onPressed: _openNetdiskShare,
                    ),
                    if (desktop)
                      BarButton(
                        icon: Icons.refresh_rounded,
                        tooltip: '刷新',
                        onPressed: explore.refresh,
                      ),
                  ],
                ),
              if (!television || explore.feed!.items.isEmpty) tabs,
              Expanded(
                child: _swipeTabs(
                  explore,
                  form,
                  _content(explore, inset, television, tabs),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  bool _swipes(FormFactor form) =>
      form == FormFactor.phone || form == FormFactor.pad;

  Widget _swipeTabs(ExploreFeed explore, FormFactor form, Widget child) {
    final tabs = explore.tabs;
    final index = tabs.indexWhere((tab) => tab.id == explore.tab.id);
    if (!_swipes(form) || index < 0) return child;
    return SwipeSwitch(
      key: ValueKey(explore.source?.id),
      index: index,
      count: tabs.length,
      ready: switch (explore.feed) {
        final feed? => feed.items.isNotEmpty || !feed.loading,
        null => true,
      },
      onSwitch: (index) => explore.select(tabs[index].id),
      onEnter: _toTop,
      child: child,
    );
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _content(
    ExploreFeed explore,
    double inset,
    bool television,
    Widget tabs,
  ) {
    final feed = explore.feed!;
    if (feed.items.isEmpty) {
      return FadeSwitcher(child: _status(feed));
    }
    final phone = AppScope.formFactorOf(context) == FormFactor.phone;
    final desktop = AppScope.formFactorOf(context) == FormFactor.window;
    final showCarousel = phone && _showPhoneCarousel(explore);
    final hero = _hero(explore, phone: phone, showCarousel: showCarousel);
    final items = showCarousel && explore.featured == null
        ? explore.items.skip(1).toList()
        : explore.items;
    return _grid(
      explore,
      feed,
      hero,
      items,
      inset,
      television,
      tabs,
      phone,
      desktop,
    );
  }

  Widget _status(DramaFeed feed) {
    if (feed.loading) {
      return const ExploreSkeleton(key: ValueKey('loading'));
    }
    if (feed.error.isNotEmpty) {
      final isChallenge =
          WebViewBridge.supported && WebViewBridge.isChallengeError(feed.error);
      final sourceId = _explore?.source?.id ?? '';
      final needsSoraniLogin =
          sourceId == 'sorani' &&
          (feed.error.contains('登录') || feed.error.contains('账号'));
      return StatusView(
        key: const ValueKey('error'),
        title: isChallenge ? '需要完成人机验证' : '暂时无法加载',
        message: feed.error,
        icon: isChallenge ? Icons.verified_user_outlined : Icons.cloud_off_rounded,
        action: isChallenge ? '完成人机验证' : '重试',
        onAction: () async {
          if (isChallenge) {
            if (sourceId.isEmpty) return;
            final ok = await WebViewBridge.verifySource(
              AppScope.of(context).repository,
              sourceId,
            );
            if (!mounted) return;
            if (ok) {
              feed.reload(force: true);
            }
            return;
          }
          feed.reload(force: true);
        },
        secondaryAction: needsSoraniLogin ? '登录青空' : '网络代理',
        onSecondaryAction: () async {
          if (needsSoraniLogin) {
            final account = await showSoraniLogin(context);
            if (mounted && account != null) feed.reload(force: true);
            return;
          }
          await openProxySettings(context, widget.store);
          if (mounted) feed.reload(force: true);
        },
      );
    }
    return StatusView(
      key: const ValueKey('empty'),
      title: '这里还没有剧',
      message: '换一个分类看看',
      icon: Icons.inbox_outlined,
      action: '刷新',
      onAction: () => feed.reload(force: true),
    );
  }

  Widget _grid(
    ExploreFeed explore,
    DramaFeed feed,
    Widget? hero,
    List<Drama> items,
    double inset,
    bool television,
    Widget tabs,
    bool phone,
    bool desktop,
  ) {
    final heroSection = hero == null
        ? const SizedBox(key: ValueKey('none'), width: double.infinity)
        : Padding(
            key: hero.key,
            padding: EdgeInsets.fromLTRB(inset, phone ? 12 : 16, inset, 0),
            child: hero,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scroll = CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (television)
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: SliverToBoxAdapter(child: tabs),
              ),
            SliverToBoxAdapter(
              child: television
                  ? heroSection
                  : AnimatedSize(
                      key: ValueKey(explore.tab.id),
                      duration: Motion.of(context, Motion.long),
                      curve: Motion.enter,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      child: FadeSwitcher(
                        alignment: Alignment.topCenter,
                        child: heroSection,
                      ),
                    ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, desktop ? 20 : 16, inset, 0),
              sliver: DramaSliverGrid(
                width: constraints.maxWidth - inset * 2,
                items: items,
                rankOf: explore.rankOf,
                autofocus:
                    television && hero == null && ShellForeground.of(context),
                heroScope: 'drama',
                showScore: !explore.recommending,
                exploreBlur: true,
                onOpen: _open,
                onMore: (drama) => quickFollow(context, widget.store, drama),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                inset,
                8,
                inset,
                television ? 27 : 16,
              ),
              sliver: SliverToBoxAdapter(child: FeedFooter(feed: feed)),
            ),
          ],
        );
        return Stack(
          children: [
            AutoLoadMore(
              feed: feed,
              child: television
                  ? scroll
                  : RefreshIndicator(
                      key: _refreshKey,
                      onRefresh: explore.refresh,
                      child: scroll,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  excluding: !feed.loading,
                  child: AnimatedOpacity(
                    opacity: feed.loading ? 1 : 0,
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.standard,
                    child: TickerMode(
                      enabled: feed.loading,
                      child: const LinearProgressIndicator(minHeight: 2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _showPhoneCarousel(ExploreFeed explore) {
    final tab = explore.tab;
    if (explore.recommending || tab.id.startsWith('app:rank:')) return true;
    if (explore.tabs.isNotEmpty && tab.id == explore.tabs.first.id) return true;
    const keywords = ['推荐', '排行', '热榜', '热门', '上新', '最新', '精选'];
    return keywords.any((word) => tab.name.contains(word));
  }

  Widget? _hero(
    ExploreFeed explore, {
    required bool phone,
    required bool showCarousel,
  }) {
    if (!phone) {
      if (explore.resume case final entry?) {
        final drama = entry.drama;
        final total = drama.episodes;
        final next = entry.finished && entry.episode < total
            ? entry.episode + 1
            : entry.episode;
        return ExploreHero(
          key: ValueKey(('resume', drama.id)),
          drama: drama,
          kicker: '继续观看',
          meta: total > 0
              ? '看到第 ${entry.episode} 集 · 共 $total 集'
              : '看到第 ${entry.episode} 集',
          progress: total > 0 ? entry.episode / total : null,
          action: '继续第 $next 集',
          onPlay: () => _open(drama, autoplay: true),
          onDetail: () => _open(drama),
        );
      }
    }
    final featured = explore.featured ??
        (showCarousel ? explore.feed?.items.firstOrNull : null);
    if (featured case final drama?) {
      final feedItems = explore.feed?.items ?? const <Drama>[];
      final carousel = phone && feedItems.length > 1
          ? feedItems.take(5).toList()
          : const <Drama>[];
      final tabName = explore.tab.name;
      final kicker = tabName == '推荐' || tabName == '全部' ? '今日推荐' : tabName;
      return ExploreHero(
        key: ValueKey(('featured', explore.tab.id, drama.id)),
        drama: drama,
        carousel: carousel,
        kicker: kicker,
        meta: [
          if (drama.category.isNotEmpty) drama.category,
          if (drama.episodes > 0) '共 ${drama.episodes} 集',
        ].join(' · '),
        action: '立即观看',
        onPlay: () => _open(drama, autoplay: true),
        onDetail: () => _open(drama),
        onPlayItem: (item) => _open(item, autoplay: true),
        onDetailItem: (item) => _open(item),
      );
    }
    return null;
  }
}
