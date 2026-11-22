import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core_bridge.dart';
import '../../drama_feed.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../../source_catalog.dart';
import '../../webview_bridge.dart';
import '../app_scope.dart';
import '../detail/detail_page.dart';
import '../settings/settings_page.dart';
import '../shell/app_shell.dart';
import '../theme/motion.dart';
import '../widgets/drama_grid.dart';
import '../widgets/follow_button.dart';
import '../widgets/focus_ring.dart';
import '../widgets/motion/motion_widgets.dart';
import '../widgets/page_header.dart';
import '../widgets/search_field.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/status_banner.dart';
import '../widgets/status_view.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.store,
    required this.source,
    this.query = '',
    this.aggregate = false,
    this.embedded = false,
  });
  final LocalStore store;
  final SourceSite source;
  final String query;
  final bool aggregate;
  final bool embedded;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _controller = TextEditingController(text: widget.query);
  final _focus = FocusNode();
  late AppRepository _repository;
  late SourceCatalog _catalog;
  DramaFeed? _results;
  String _submitted = '';
  late bool _aggregate;

  @override
  void initState() {
    super.initState();
    _aggregate = widget.aggregate;
  }

  int _searchGen = 0;
  bool _aggLoading = false;
  int _aggDone = 0;
  int _aggTotal = 0;
  List<Drama> _aggItems = const [];
  final Map<String, String> _aggErrors = {};
  String _aggSourceFilter = '';
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _suggestion = 0;
  final _shownSuggestions = <Object>{};
  bool _ready = false;

  SourceSite get _activeSource {
    if (!widget.embedded || widget.store.source.isEmpty) return widget.source;
    return SourceSite.byId(widget.store.source);
  }

  List<SourceSite> get _searchableSources {
    final list = [
      for (final site in widget.store.sources)
        if (site.onlineSearch && site.id != 'quark') site,
    ];
    if (_activeSource.onlineSearch &&
        _activeSource.id != 'quark' &&
        !list.any((site) => site.id == _activeSource.id)) {
      list.insert(0, _activeSource);
    }
    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _repository = AppScope.of(context).repository;
    _catalog = SourceCatalog(_repository, _activeSource);
    if (widget.query.trim().isNotEmpty) _submit(widget.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestion++;
    _searchGen++;
    unawaited(_repository.cancelSuggestions());
    _results?.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _forget(String query) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(widget.store.forgetSearch(query).catchError((Object _) {}));
  }

  void _submit(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _focus.unfocus();
    _debounce?.cancel();
    _suggestion++;
    _searchGen++;
    unawaited(widget.store.rememberSearch(query).catchError((Object _) {}));
    _results?.dispose();
    _results = null;
    if (_aggregate) {
      final sources = _searchableSources;
      setState(() {
        _submitted = query;
        _suggestions = const [];
        _aggItems = const [];
        _aggErrors.clear();
        _aggSourceFilter = '';
        _aggDone = 0;
        _aggTotal = sources.length;
        _aggLoading = sources.isNotEmpty;
      });
      if (sources.isNotEmpty) {
        unawaited(_runAggregate(query, sources, _searchGen));
      }
      return;
    }
    final results = _results = DramaFeed(
      load: (page, _) => _catalog.search(query, page: page),
    )..addListener(() => setState(() {}));
    unawaited(results.reload());
    setState(() {
      _submitted = query;
      _suggestions = const [];
      _aggLoading = false;
      _aggItems = const [];
      _aggErrors.clear();
      _aggSourceFilter = '';
      _aggDone = 0;
      _aggTotal = 0;
    });
  }

  Future<void> _runAggregate(
    String query,
    List<SourceSite> sources,
    int gen, {
    bool append = false,
  }) async {
    var cursor = 0;
    final seen = <String>{
      if (append)
        for (final item in _aggItems) '${item.source}:${item.id}',
    };
    final workerCount = math.min(6, sources.length);
    Future<void> worker() async {
      while (cursor < sources.length) {
        if (!mounted || gen != _searchGen) return;
        final site = sources[cursor++];
        try {
          final page = await _repository.catalog(
            site.id,
            query: query,
            page: 1,
          );
          if (!mounted || gen != _searchGen) return;
          final added = <Drama>[];
          for (final item in page.items) {
            final key = '${item.source}:${item.id}';
            if (seen.add(key)) {
              added.add(item);
            }
          }
          setState(() {
            _aggDone++;
            if (added.isNotEmpty) {
              _aggItems = [..._aggItems, ...added];
            }
          });
        } catch (error) {
          if (!mounted || gen != _searchGen) return;
          setState(() {
            _aggDone++;
            _aggErrors[site.id] = '$error';
          });
        }
      }
    }

    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    if (!mounted || gen != _searchGen) return;
    setState(() => _aggLoading = false);
  }

  void _setAggregate(bool aggregate) {
    if (_aggregate == aggregate) return;
    setState(() => _aggregate = aggregate);
    if (_submitted.isNotEmpty) {
      _submit(_submitted);
    }
  }

  void _changed(String text) {
    _debounce?.cancel();
    final query = text.trim();
    final generation = ++_suggestion;
    if (!_activeSource.searchSuggestions || query.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final items = await _repository.suggestions(_activeSource.id, query);
        if (mounted && generation == _suggestion) {
          setState(() => _suggestions = items);
        }
      } catch (_) {}
    });
  }

  void _open(Drama drama) => openPage<void>(
    context,
    (_) => DetailPage(store: widget.store, drama: drama),
  );

  @override
  Widget build(BuildContext context) {
    if (_ready && _catalog.source.id != _activeSource.id) {
      _catalog = SourceCatalog(_repository, _activeSource);
    }
    final searchable = _searchableSources;
    final canAggregate = searchable.length > 1;
    final hint = _aggregate && canAggregate
        ? '在全网 ${searchable.length} 个站源中聚合搜索'
        : '在 ${_activeSource.name} 中搜索';
    final field = SearchField(
      hint: hint,
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.query.isEmpty,
      onChanged: _changed,
      onSubmitted: _submit,
      letterKeyboard: widget.store.televisionKeyboard,
      matches: _activeSource.searchSuggestions && !_aggregate
          ? (query) => _repository.suggestions(_activeSource.id, query)
          : null,
    );
    final modeBar = canAggregate ? _modeBar(context, searchable.length) : null;
    if (widget.embedded) {
      final phone = AppScope.formFactorOf(context) == FormFactor.phone;
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PageHeader(title: '搜索'),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 20 : 24,
                  0,
                  phone ? 12 : 16,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(child: field),
                    if (canAggregate)
                      TextButton(
                        onPressed: () => _setAggregate(!_aggregate),
                        child: Text(_aggregate ? '聚合' : '本站'),
                      ),
                  ],
                ),
              ),
              if (_aggregate && canAggregate)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 20 : 24,
                    4,
                    phone ? 20 : 24,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '按站源保留结果，同名不合并',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Expanded(child: FadeSwitcher(child: _body(context))),
            ],
          ),
        ),
      );
    }
    if (AppScope.of(context).television) {
      return Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                televisionInset,
                27,
                televisionInset,
                0,
              ),
              child: field,
            ),
            if (modeBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  televisionInset,
                  10,
                  televisionInset,
                  0,
                ),
                child: modeBar,
              ),
            Expanded(child: FadeSwitcher(child: _body(context))),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(padding: const EdgeInsets.only(right: 16), child: field),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (modeBar != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppScope.formFactorOf(context) == FormFactor.phone ? 16 : 24,
                  6,
                  AppScope.formFactorOf(context) == FormFactor.phone ? 16 : 24,
                  2,
                ),
                child: modeBar,
              ),
            Expanded(child: FadeSwitcher(child: _body(context))),
          ],
        ),
      ),
    );
  }

  Widget _modeBar(BuildContext context, int total) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget pill(String label, bool selected, VoidCallback onTap) => FocusRing(
      radius: 999,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.16)
            : colors.surfaceContainerHigh.withValues(alpha: 0.6),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? colors.primary.withValues(alpha: 0.55)
                : colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: text.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        pill('当前站源', !_aggregate, () => _setAggregate(false)),
        const SizedBox(width: 8),
        pill('全网聚合 ($total)', _aggregate, () => _setAggregate(true)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final television = AppScope.of(context).television;
    if (_suggestions.isNotEmpty && _controller.text.trim() != _submitted) {
      return ListView(
        key: const ValueKey('suggest'),
        padding: television
            ? const EdgeInsets.fromLTRB(televisionInset, 8, televisionInset, 27)
            : const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (index, item) in _suggestions.indexed)
            EnterOnce(
              key: ValueKey(index),
              id: item,
              played: _shownSuggestions,
              index: index,
              child: TileFocus(
                builder: (focusNode) => ListTile(
                  focusNode: focusNode,
                  leading: const Icon(Icons.search_rounded),
                  title: Text(item),
                  onTap: () => _submit(item),
                ),
              ),
            ),
        ],
      );
    }
    if (_aggregate && _submitted.isNotEmpty) {
      return _aggregateBody(context);
    }
    final results = _results;
    if (results == null) {
      return KeyedSubtree(
        key: const ValueKey('recent'),
        child: _recent(context),
      );
    }
    if (results.items.isEmpty) {
      if (results.loading) {
        return const StatusView.loading(
          key: ValueKey('loading'),
          title: '正在搜索',
        );
      }
      if (results.error.isNotEmpty) {
        final isChallenge =
            WebViewBridge.supported &&
            WebViewBridge.isChallengeError(results.error);
        return StatusView(
          key: const ValueKey('error'),
          title: isChallenge ? '需要完成人机验证' : '搜索失败',
          message: results.error,
          icon: isChallenge
              ? Icons.verified_user_outlined
              : Icons.cloud_off_rounded,
          action: isChallenge ? '完成人机验证' : '重试',
          onAction: () async {
            if (isChallenge) {
              final ok = await WebViewBridge.verifySource(
                _repository,
                _activeSource.id,
              );
              if (!mounted) return;
              if (ok) {
                results.reload();
              }
              return;
            }
            results.reload();
          },
          secondaryAction: '网络代理',
          onSecondaryAction: () async {
            await openProxySettings(context, widget.store);
            if (mounted) results.reload();
          },
        );
      }
      return StatusView(
        key: const ValueKey('empty'),
        title: '没有找到「$_submitted」',
        message: '换个关键词试试',
        icon: Icons.search_off_rounded,
      );
    }
    final inset = television
        ? televisionInset
        : AppScope.formFactorOf(context) == FormFactor.phone
        ? 16.0
        : 24.0;
    return LayoutBuilder(
      key: ValueKey(('results', _submitted)),
      builder: (context, constraints) => AutoLoadMore(
        feed: results,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                inset,
                television ? 16 : 8,
                inset,
                0,
              ),
              sliver: DramaSliverGrid(
                width: constraints.maxWidth - inset * 2,
                items: results.items,
                autofocus: television,
                heroScope: 'drama',
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
              sliver: SliverToBoxAdapter(child: FeedFooter(feed: results)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aggregateBody(BuildContext context) {
    final television = AppScope.of(context).television;
    if (_aggItems.isEmpty) {
      if (_aggLoading) {
        return StatusView.loading(
          key: const ValueKey('agg-loading'),
          title: '正在全网聚合搜索（$_aggDone / $_aggTotal）',
        );
      }
      if (_aggTotal > 0 && _aggErrors.length == _aggTotal) {
        return StatusView(
          key: const ValueKey('agg-error'),
          title: '全网搜索失败',
          message: '所有可搜索站源均请求失败，请检查网络或切换当前站源后重试',
          icon: Icons.cloud_off_rounded,
          action: '重试',
          onAction: () => _submit(_submitted),
        );
      }
      return StatusView(
        key: const ValueKey('agg-empty'),
        title: '没有找到「$_submitted」',
        message: '已搜索 $_aggTotal 个站源，换个关键词试试',
        icon: Icons.search_off_rounded,
      );
    }
    final counts = <String, int>{};
    for (final item in _aggItems) {
      counts[item.source] = (counts[item.source] ?? 0) + 1;
    }
    final sourceOrder = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final activeFilter =
        _aggSourceFilter.isNotEmpty && counts.containsKey(_aggSourceFilter)
        ? _aggSourceFilter
        : '';
    final displayed = activeFilter.isEmpty
        ? _aggItems
        : [
            for (final item in _aggItems)
              if (item.source == activeFilter) item,
          ];
    final inset = television
        ? televisionInset
        : AppScope.formFactorOf(context) == FormFactor.phone
        ? 16.0
        : 24.0;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      key: ValueKey(('agg-results', _submitted)),
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, 8, inset, 4),
              child: Row(
                children: [
                  if (_aggLoading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _aggLoading
                          ? '正在搜索 $_aggDone / $_aggTotal 个站源，已找到 ${_aggItems.length} 条'
                          : '已完成 $_aggDone 个站源搜索，共找到 ${_aggItems.length} 条结果',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sourceOrder.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('全部 (${_aggItems.length})'),
                        selected: activeFilter.isEmpty,
                        onSelected: (_) =>
                            setState(() => _aggSourceFilter = ''),
                      ),
                    ),
                    for (final sourceId in sourceOrder)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${SourceSite.byId(sourceId).name} (${counts[sourceId]})',
                          ),
                          selected: activeFilter == sourceId,
                          onSelected: (_) =>
                              setState(() => _aggSourceFilter = sourceId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_aggErrors.isNotEmpty)
            SliverToBoxAdapter(child: _aggregateNotices(context, inset)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, television ? 27 : 20),
            sliver: AppScope.formFactorOf(context) == FormFactor.phone
                ? SliverList.separated(
                    itemCount: displayed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final drama = displayed[index];
                      return SearchResultTile(
                        drama: drama,
                        onTap: () => _open(drama),
                      );
                    },
                  )
                : DramaSliverGrid(
                    width: constraints.maxWidth - inset * 2,
                    items: displayed,
                    autofocus: television,
                    subtitleOf: (drama) {
                      final siteName = SourceSite.byId(drama.source).name;
                      if (drama.category.isNotEmpty) {
                        return '$siteName · ${drama.category}';
                      }
                      if (drama.badge.isNotEmpty) {
                        return '$siteName · ${drama.badge}';
                      }
                      return siteName;
                    },
                    onOpen: _open,
                    onMore: (drama) =>
                        quickFollow(context, widget.store, drama),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _aggregateNotices(BuildContext context, double inset) {
    final failed = _aggErrors.keys.toList();
    final challenge = failed
        .where(
          (id) =>
              WebViewBridge.supported &&
              WebViewBridge.isChallengeError(_aggErrors[id] ?? ''),
        )
        .toList();
    final names = [for (final id in failed) SourceSite.byId(id).name].join('、');
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
      child: Column(
        spacing: 8,
        children: [
          if (challenge.isNotEmpty)
            StatusBanner(
              tone: StatusTone.warning,
              title: '需验证',
              message:
                  '${SourceSite.byId(challenge.first).name} 需要完成人机验证后才能继续。不会跳过验证，也不会自动换源循环。',
              actionLabel: '去验证',
              onAction: () async {
                final ok = await WebViewBridge.verifySource(
                  _repository,
                  challenge.first,
                );
                if (!mounted) return;
                if (ok) _retrySources([SourceSite.byId(challenge.first)]);
              },
            ),
          StatusBanner(
            tone: StatusTone.danger,
            title: '部分失败',
            message: '$names 暂时无响应。已保留其它站的部分结果。',
            actionLabel: '重试',
            onAction: () =>
                _retrySources([for (final id in failed) SourceSite.byId(id)]),
          ),
        ],
      ),
    );
  }

  void _retrySources(List<SourceSite> sources) {
    if (sources.isEmpty || _submitted.isEmpty) return;
    final gen = ++_searchGen;
    setState(() {
      for (final site in sources) {
        _aggErrors.remove(site.id);
      }
      _aggLoading = true;
      _aggTotal = _aggDone + sources.length;
    });
    unawaited(_runAggregate(_submitted, sources, gen, append: true));
  }

  Widget _recent(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final recent = widget.store.recentSearches;
      return FadeSwitcher(child: _recentContent(context, recent));
    },
  );

  Widget _recentContent(BuildContext context, List<String> recent) {
    if (recent.isEmpty) {
      final total = _searchableSources.length;
      return StatusView(
        key: const ValueKey('empty'),
        title: _aggregate && total > 1
            ? '在全网 $total 个站源中聚合搜索'
            : '在 ${_activeSource.name} 中搜索',
        message: '输入剧名或关键词',
        icon: Icons.search_rounded,
      );
    }
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('recent'),
      padding: AppScope.of(context).television
          ? const EdgeInsets.fromLTRB(televisionInset, 8, televisionInset, 27)
          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近搜索',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FocusRing(
              radius: 999,
              child: TextButton(
                onPressed: () => widget.store.clearRecentSearches().catchError(
                  (Object _) {},
                ),
                child: const Text('清空'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.enter,
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in recent)
                FocusRing(
                  radius: 8,
                  child: GestureDetector(
                    onLongPress: () => _forget(query),
                    onSecondaryTap: () => _forget(query),
                    child: ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(query),
                      onPressed: () => _submit(query),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
