import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../drama_details.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../../webview_bridge.dart';
import '../app_scope.dart';
import '../downloads/download_picker_page.dart';
import '../netdisk/netdisk_page.dart';
import '../player/playback_handle.dart';
import '../player/playback_page.dart';
import '../settings/settings_page.dart';
import '../settings/sorani_account_view.dart';
import '../shell/app_shell.dart';
import '../widgets/cover_backdrop.dart';
import '../widgets/cover_image.dart';
import '../widgets/focus_ring.dart';
import '../widgets/follow_button.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/accent.dart';
import '../widgets/stage_backdrop.dart';
import '../widgets/motion/motion_widgets.dart';
import '../widgets/status_view.dart';
import '../widgets/swipe_switch.dart';
import 'detail_metrics.dart';
import 'detail_routes.dart';
import 'season_strip.dart';
import 'television_detail.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.store,
    required this.drama,
    this.autoplay = false,
  });
  final LocalStore store;
  final Drama drama;
  final bool autoplay;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DramaDetails? _details;
  PlaybackHandle? _handle;
  bool _watching = false;
  var _currentEpisode = GlobalKey();
  String _keyedDrama = '';
  bool _expanded = false;
  final _played = <Object>{};
  final _groupKeys = <GlobalKey>[];
  String _routeDramaId = '';
  String _selectedRoute = '';
  int _routeGroup = 0;
  final _televisionDetail = GlobalKey<TelevisionDetailState>();
  AccentScheme _accent = AccentScheme.fallback;
  String _accentKey = '';
  String _coverPath = '';
  bool _entered = false;
  PlaybackHandle? _watched;
  late final bool _direct = AppScope.formFactorOf(context) == FormFactor.phone;
  late bool _autoplayPending = widget.autoplay || _direct;
  late bool _curtain = widget.autoplay || _direct;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _details ??= DramaDetails(
      AppScope.of(context).repository,
      widget.store,
      widget.drama,
    )..addListener(_detailsChanged);
  }

  @override
  void dispose() {
    _handle?.dispose();
    _details?.dispose();
    super.dispose();
  }

  bool get _canDownload =>
      AppScope.of(context).repository.supportsDownloads &&
      widget.store.canDownload;

  bool get _ready => !_details!.loading && _details!.episodes.isNotEmpty;

  Future<void> _refresh() async {
    final details = _details!;
    await details.load();
    if (!mounted || details.error == null || details.episodes.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(details.error!)));
  }

  double _startAt(int index, {required bool resume}) {
    final watch = _details!.watch;
    return resume &&
            watch?.episode == _details!.episodes[index].number &&
            !watch!.finished
        ? watch.position
        : 0.0;
  }

  DramaDetail get _detail {
    final details = _details!;
    return DramaDetail(
      details.drama,
      details.episodes,
      warning: details.warning,
      seasons: details.seasons,
    );
  }

  PlaybackHandle _open(
    int index, {
    required double position,
    bool autoplay = true,
  }) => PlaybackHandle(
    repository: AppScope.of(context).repository,
    store: widget.store,
    detail: _detail,
    index: index,
    position: position,
    autoplay: autoplay,
    preopen: widget.store.playbackPreferences.preopens(
      television: AppScope.of(context).television,
    ),
  );

  void _detailsChanged() {
    final seasons = _details!.seasons;
    _handle?.session.syncSeasons(seasons);
    _watched?.session.syncSeasons(seasons);
    _preopen();
    unawaited(_autoplay());
  }

  Future<void> _autoplay() async {
    final details = _details!;
    if (!_autoplayPending || !mounted || details.loading) return;
    _autoplayPending = false;
    if (_ready && details.allowed) {
      if (_direct) await _awaitVideoSize();
      if (!mounted) return;
      final watched = await _play(details.resumeIndex, resume: true);
      if (!mounted) return;
      if (_direct && watched) {
        Navigator.pop(context);
        return;
      }
    }
    if (_curtain) {
      setState(() => _curtain = false);
    } else if (AppScope.of(context).television &&
        details.currentIndex == null) {
      _televisionDetail.currentState?.focusPlay();
    }
  }

  Future<void> _awaitVideoSize() async {
    final session = _handle?.session;
    if (session == null) return;
    final known = Completer<void>();
    void check() {
      if ((session.aspectKnown || session.error != null) &&
          !known.isCompleted) {
        known.complete();
      }
    }

    session.addListener(check);
    check();
    try {
      await known.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    } finally {
      session.removeListener(check);
    }
  }

  void _liftCurtainAfter(Animation<double> entering) {
    void lift(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      entering.removeStatusListener(lift);
      if (!mounted || !_curtain) return;
      _entered = true;
      setState(() => _curtain = false);
    }

    entering.addStatusListener(lift);
    lift(entering.status);
  }

  void _preopen() {
    final details = _details!;
    if (_handle != null ||
        _watching ||
        !mounted ||
        !_ready ||
        !details.allowed) {
      return;
    }
    final index = details.resumeIndex;
    _handle = _open(
      index,
      position: _startAt(index, resume: true),
      autoplay: false,
    );
  }

  Future<bool> _play(int index, {bool resume = false}) async {
    final details = _details!;
    final episode = details.episodes[index];
    if (episode.vip &&
        SourceSite.byId(details.drama.source).vipPrompt &&
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('这是一集 VIP 内容'),
                content: const Text('站源可能只提供试看或限制播放。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('尝试播放'),
                  ),
                ],
              ),
            ) !=
            true) {
      return false;
    }
    if (!mounted || !details.allowed) return false;
    final position = _startAt(index, resume: resume);
    final handle = _handle ?? _open(index, position: position);
    _handle = null;
    handle.session.syncSeasons(details.seasons);
    handle.session.start(index, position: position);
    _watching = true;
    _watched = handle;
    final route = MaterialPageRoute<void>(
      builder: (_) => PlaybackPage(store: widget.store, handle: handle),
    );
    final closed = Navigator.of(context, rootNavigator: true).push(route);
    if (_curtain && !_direct) _liftCurtainAfter(route.animation!);
    await closed;
    _watching = false;
    _watched = null;
    if (!mounted || _curtain) return true;
    final played = handle.session.detail.drama.id;
    if (played != details.drama.id) {
      final season = details.seasons
          .where((season) => season.drama.id == played)
          .firstOrNull;
      if (season != null) await details.selectSeason(season);
      if (!mounted) return true;
    }
    if (AppScope.of(context).television) _focusWatched(details);
    return true;
  }

  void _focusWatched(DramaDetails details) {
    final index = details.currentIndex;
    if (index == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _televisionDetail.currentState?.focusEpisode(index);
    });
  }

  void _download() => openPage<void>(
    context,
    (_) => DownloadPickerPage(store: widget.store, detail: _detail),
  );

  void _locate(int index) {
    final details = _details!;
    final scope = _resolveEpisodeScope(details);
    if (scope.routes.isNotEmpty) {
      for (final route in scope.routes) {
        final pos = route.entries.indexWhere((entry) => entry.index == index);
        if (pos >= 0) {
          setState(() {
            _selectedRoute = route.name;
            _routeGroup = pos ~/ episodeGroupSize;
          });
          break;
        }
      }
    } else {
      details.selectGroup(index ~/ episodeGroupSize);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentEpisode.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _coverLoadedFor = '';

  /// 解析封面到本地缓存文件，成功后取色。
  Future<void> _loadCover() async {
    final key = '${widget.drama.source}:${widget.drama.id}';
    if (_coverLoadedFor == key) return;
    _coverLoadedFor = key;
    try {
      final path = await AppScope.of(context).repository.cover(widget.drama);
      if (!mounted || path == _coverPath) return;
      setState(() => _coverPath = path);
      _syncAccent(path);
    } catch (_) {}
  }

  /// 封面变了才重新取色；取到之前先用品牌色，不阻塞页面。
  void _syncAccent(String cover) {
    if (cover == _accentKey) return;
    _accentKey = cover;
    if (cover.isEmpty) {
      _accent = AccentScheme.fallback;
      return;
    }
    AccentPicker.fromSource(cover).then((value) {
      if (!mounted || value == null || _accentKey != cover) return;
      setState(() => _accent = value);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _details!,
    builder: (context, _) {
      final details = _details!;
      _renewKeys(details.drama.id);
      if (!details.allowed) {
        return Scaffold(
          appBar: AppBar(),
          body: const StatusView(
            title: '当前用户无权访问',
            message: '请返回剧库后重新选择。',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      if (_curtain) return _transition(widget.drama);
      final form = AppScope.formFactorOf(context);
      final coverKey = '${widget.drama.source}:${widget.drama.id}';
      if (_coverPath.isEmpty && _coverLoadedFor != coverKey) {
        unawaited(_loadCover());
      }
      if (form == FormFactor.television) return _televisionPage(details);
      final page =
          (form == FormFactor.phone || MediaQuery.sizeOf(context).width < 840)
          ? _phonePage(details)
          : _widePage(details, desktop: form == FormFactor.window);
      return AccentStage(accent: _accent, cover: _coverPath, child: page);
    },
  );

  PreferredSizeWidget _appBar(DramaDetails details, double height) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: height,
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? colors.surfaceContainer
            : Colors.transparent,
      ),
      actions: [
        IconButton(
          tooltip: '更新剧集信息',
          onPressed: details.loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _withBackdrop(Drama drama, double height, Widget child) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: height,
          child: CoverBackdrop(
            drama: drama,
            sigma: 30,
            opacity: theme.brightness == Brightness.dark ? 0.68 : 0.48,
            overlay: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.45, 0.94],
              colors: [
                surface.withValues(alpha: 0.08),
                surface.withValues(alpha: 0.55),
                surface,
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _enter(int index, Widget child) => EnterOnce(
    id: 'section-$index',
    played: _played,
    index: index,
    child: child,
  );

  Widget _phonePage(DramaDetails details) {
    const m = detailPhoneMetrics;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final drama = details.drama;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(details, kToolbarHeight),
      body: RefreshIndicator(
        edgeOffset: top,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _withBackdrop(
                drama,
                top +
                    290 +
                    math.max(
                      0.0,
                      (MediaQuery.textScalerOf(context).scale(1.0) - 1.0) * 80,
                    ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, top, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 14,
                        children: [
                          _cover(drama, m),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _enter(
                                0,
                                _followingHeadline(details, m, 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_stats(drama, m) case final stats?)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _enter(1, stats),
                        ),
                      if (_tags(drama, m) case final tags?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _enter(2, tags),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          spacing: 10,
                          children: [
                            Expanded(child: _playButton(details, m)),
                            if (_canDownload)
                              FocusRing(
                                radius: m.button / 2,
                                child: IconButton.filledTonal(
                                  tooltip: '下载选集',
                                  onPressed: _ready ? _download : null,
                                  style: IconButton.styleFrom(
                                    minimumSize: Size.square(m.button),
                                  ),
                                  icon: const Icon(Icons.download_rounded),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (drama.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _enter(3, _description(drama, m)),
                        ),
                      if (details.warning.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _warning(details.warning, m),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (details.seasons.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: _seasonRow(details, m),
                ),
              ),
            if (details.episodes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _episodeStatus(details),
              )
            else ...[
              Builder(
                builder: (context) {
                  final scope = _resolveEpisodeScope(details);
                  return SliverMainAxisGroup(
                    slivers: [
                      if (scope.routes.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Text(
                              '线路',
                              style: TextStyle(
                                fontSize: m.section,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                (MediaQuery.textScalerOf(context).scale(13) +
                                        28)
                                    .clamp(m.chip + 10, 64.0),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                              itemCount: scope.routes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => _routeChip(
                                m,
                                scope.routes[index],
                                selected:
                                    scope.routes[index].name == scope.routeName,
                                currentIndex: details.currentIndex,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: _episodeHeader(details, m, scope: scope),
                        ),
                      ),
                      if (scope.groupCount > 1)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                (MediaQuery.textScalerOf(context).scale(13) +
                                        24)
                                    .clamp(m.chip + 4, 60.0),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              itemCount: scope.groupCount,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, group) =>
                                  _groupChip(details, m, group, scope: scope),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _swipeGroups(details, m, scope: scope),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _widePage(DramaDetails details, {required bool desktop}) {
    final m = desktop ? detailDesktopMetrics : detailPadMetrics;
    final top = MediaQuery.paddingOf(context).top + 64;
    final inset = desktop ? 32.0 : 24.0;
    final gap = desktop ? 40.0 : 32.0;
    final side = desktop ? 420.0 : 380.0;
    final drama = details.drama;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: desktop ? 20 : 18,
          children: [
            _cover(drama, m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _enter(0, _followingHeadline(details, m, 4)),
              ),
            ),
          ],
        ),
        if (_stats(drama, m) case final stats?)
          Padding(
            padding: EdgeInsets.only(top: desktop ? 18 : 16),
            child: _enter(1, stats),
          ),
        if (_tags(drama, m) case final tags?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _enter(2, tags),
          ),
        Padding(
          padding: EdgeInsets.only(top: desktop ? 22 : 20),
          child: Row(
            spacing: 12,
            children: [
              Expanded(child: _playButton(details, m)),
              if (_canDownload) _downloadButton(m),
            ],
          ),
        ),
        if (drama.description.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: desktop ? 22 : 20),
            child: _enter(3, _description(drama, m)),
          ),
        if (details.warning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _warning(details.warning, m),
          ),
      ],
    );
    final scope = details.episodes.isEmpty
        ? null
        : _resolveEpisodeScope(details);
    final episodeList = details.episodes.isEmpty
        ? SizedBox(
            key: const ValueKey('status'),
            height: 320,
            child: _episodeStatus(details),
          )
        : Column(
            key: const ValueKey('episodes'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: desktop ? 44 : 48,
                child: _episodeHeader(details, m, scope: scope),
              ),
              if (scope != null && scope.routes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final route in scope.routes)
                        _routeChip(
                          m,
                          route,
                          selected: route.name == scope.routeName,
                          currentIndex: details.currentIndex,
                        ),
                    ],
                  ),
                ),
              if (scope != null && scope.groupCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var group = 0; group < scope.groupCount; group++)
                        _groupChip(details, m, group, scope: scope),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: desktop
                    ? _grid(details, m, scope: scope)
                    : _swipeGroups(details, m, scope: scope),
              ),
            ],
          );
    final episodes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details.seasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _seasonRow(details, m),
          ),
        FadeSwitcher(alignment: Alignment.topCenter, child: episodeList),
      ],
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(details, 64),
      body: SingleChildScrollView(
        child: _withBackdrop(
          drama,
          top + 336,
          Padding(
            padding: EdgeInsets.fromLTRB(inset, top + 4, inset, 40),
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= side + gap + 480
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: gap,
                      children: [
                        SizedBox(width: side, child: info),
                        Expanded(child: episodes),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: gap,
                      children: [info, episodes],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _televisionPage(DramaDetails details) {
    if (_ready && !_entered) {
      _entered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _televisionDetail.currentState?.focusPlay();
      });
    }
    return Scaffold(
      body: TelevisionDetail(
        key: _televisionDetail,
        details: details,
        store: widget.store,
        status: _episodeStatus(details, autofocus: true),
        onResume: _ready
            ? () => _play(details.resumeIndex, resume: true)
            : null,
        onEpisode: _play,
        onSeason: (season) => unawaited(_selectSeason(season)),
        onDescription: () => showDialog<void>(
          context: context,
          builder: (_) => _DescriptionDialog(drama: details.drama),
        ),
      ),
    );
  }

  Widget _transition(Drama drama) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CoverBackdrop(
            drama: drama,
            sigma: 28,
            opacity: theme.brightness == Brightness.dark ? 0.68 : 0.5,
            overlay: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [surface.withValues(alpha: .15), surface],
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x73000000),
                            blurRadius: 32,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          final size = MediaQuery.sizeOf(context);
                          final coverWidth = math
                              .min(size.width * 0.46, size.height * 0.28)
                              .clamp(108.0, 188.0);
                          return SizedBox(
                            width: coverWidth,
                            height: coverWidth * 1.5,
                            child: DramaCover(
                              drama: drama,
                              radius: 18,
                              details: false,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(Drama drama, DetailMetrics m, {bool hero = true}) {
    final width = AppScope.formFactorOf(context) == FormFactor.phone
        ? math.min(m.cover.width, MediaQuery.sizeOf(context).width * 0.31)
        : m.cover.width;
    final size = Size(width, width * (m.cover.height / m.cover.width));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(m.coverRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox.fromSize(
        size: size,
        child: DramaCover(
          drama: drama,
          radius: m.coverRadius,
          heroScope: hero ? 'drama' : null,
        ),
      ),
    );
  }

  Widget _headline(
    DramaDetails details,
    DetailMetrics m, {
    double spacing = 8,
    List<Widget> trailing = const [],
  }) {
    final drama = details.drama;
    final colors = Theme.of(context).colorScheme;
    Widget pill(String label, {Color? textColor, Color? fillColor}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                fillColor ??
                colors.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              label,
              style: TextStyle(
                fontSize: m.tag,
                fontWeight: FontWeight.w500,
                color: textColor ?? colors.onSurfaceVariant,
              ),
            ),
          ),
        );
    final meta = [
      SourceSite.byId(drama.source).name,
      if (drama.episodes > 0) '共 ${drama.episodes} 集',
      if (drama.releaseStatus.isNotEmpty && drama.releaseStatus != 'unknown')
        drama.releaseLabel,
      if (drama.category.isNotEmpty) drama.category,
      if (drama.source == 'huangdou')
        drama.vipStatus == null
            ? 'VIP 状态待补齐'
            : drama.vip
            ? 'VIP 内容'
            : '免费内容',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing,
      children: [
        Text(
          drama.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: m.title,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (drama.score.isNotEmpty)
              pill(
                '★ ${drama.score}',
                textColor: const Color(0xFFFFC542),
                fillColor: const Color(0x28FFC542),
              ),
            for (final item in meta) pill(item),
          ],
        ),
        ...trailing,
      ],
    );
  }

  Widget _followingHeadline(
    DramaDetails details,
    DetailMetrics m,
    double top,
  ) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: m.cover.height - top),
    child: IntrinsicHeight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headline(details, m),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FollowPill(
              store: widget.store,
              drama: details.drama,
              height: m.follow,
            ),
          ),
        ],
      ),
    ),
  );

  Widget? _stats(Drama drama, DetailMetrics m) {
    final stats = [
      if (drama.onlineDate.isNotEmpty) '${drama.onlineDate} 上线',
      if (drama.views.isNotEmpty && drama.views != '0') '播放 ${drama.views}',
    ];
    if (stats.isEmpty) return null;
    return Text(
      stats.join(' · '),
      style: TextStyle(
        fontSize: m.note,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget? _tags(Drama drama, DetailMetrics m) {
    if (drama.tags.isEmpty) return null;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in drama.tags.take(12))
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text(tag, style: TextStyle(fontSize: m.tag)),
            ),
          ),
      ],
    );
  }

  Widget _description(Drama drama, DetailMetrics m) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: m.body,
      height: m.bodyHeight,
      color: colors.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _exceeds(
          drama.description,
          style,
          3,
          constraints.maxWidth,
        );
        final label = Text(_expanded ? '收起简介' : '展开简介');
        void toggle() => setState(() => _expanded = !_expanded);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.of(context, Motion.long),
              curve: Motion.standard,
              alignment: Alignment.topCenter,
              child: Text(
                drama.description,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (overflows)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: toggle,
                  child: FadeSwitcher(
                    duration: Motion.short,
                    child: KeyedSubtree(key: ValueKey(_expanded), child: label),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _exceeds(String text, TextStyle style, int maxLines, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final exceeds = painter.didExceedMaxLines;
    painter.dispose();
    return exceeds;
  }

  Widget _warning(String text, DetailMetrics m) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.error_outline_rounded,
            size: m.note + 3,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: m.note, height: 1.5, color: color),
          ),
        ),
      ],
    );
  }

  Widget _playButton(DramaDetails details, DetailMetrics m) {
    final label = details.watch != null && details.episodes.isNotEmpty
        ? '继续播放 · 第 ${details.episodes[details.resumeIndex].number} 集'
        : '立即播放';
    return FocusRing(
      radius: m.button / 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _ready ? AppTheme.brandGradient : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _ready
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF2E54).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: FilledButton.icon(
          key: const ValueKey('detail-play'),
          onPressed: _ready
              ? () => _play(details.resumeIndex, resume: true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: _ready ? Colors.transparent : null,
            shadowColor: Colors.transparent,
            foregroundColor: _ready ? Colors.white : null,
            minimumSize: Size(0, m.button),
            iconSize: m.buttonIcon,
            textStyle: TextStyle(
              fontSize: m.buttonText,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: FadeSwitcher(
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(DetailMetrics m) => FocusRing(
    radius: m.button / 2,
    child: FilledButton.tonalIcon(
      onPressed: _ready ? _download : null,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, m.button),
        iconSize: m.buttonIcon - 2,
        textStyle: TextStyle(
          fontSize: m.buttonText - 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.download_rounded),
      label: const Text('下载选集'),
    ),
  );

  Widget _episodeStatus(DramaDetails details, {bool autofocus = false}) =>
      FadeSwitcher(
        child: details.loading
            ? const StatusView.loading(key: ValueKey('loading'))
            : _episodeError(details, autofocus),
      );

  Widget _episodeError(DramaDetails details, bool autofocus) {
    final error = details.error;
    final isChallenge =
        error != null &&
        WebViewBridge.supported &&
        WebViewBridge.isChallengeError(error);
    return StatusView(
      key: const ValueKey('error'),
      title: isChallenge
          ? '需要完成人机验证'
          : (error != null ? '剧集信息暂时不可用' : '暂时没有可播放的集数'),
      message: error ?? '可以更新剧集信息后重试。',
      icon: isChallenge
          ? Icons.verified_user_outlined
          : Icons.error_outline_rounded,
      action: isChallenge ? '完成人机验证' : '重试',
      onAction: () async {
        if (isChallenge) {
          final ok = await WebViewBridge.verifySource(
            AppScope.of(context).repository,
            widget.drama.source,
          );
          if (!mounted) return;
          if (ok) {
            details.load();
          }
          return;
        }
        details.load();
      },
      secondaryAction: error != null
          ? (isNetdiskAuthError(error, source: widget.drama.source)
                ? '去登录网盘'
                : widget.drama.source == 'sorani' &&
                      (error.contains('登录') || error.contains('账号'))
                ? '登录青空'
                : '网络代理')
          : null,
      onSecondaryAction: error != null
          ? () async {
              if (isNetdiskAuthError(error, source: widget.drama.source)) {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NetdiskPage(store: widget.store),
                  ),
                );
                if (mounted) details.load();
                return;
              }
              if (widget.drama.source == 'sorani' &&
                  (error.contains('登录') || error.contains('账号'))) {
                final account = await showSoraniLogin(context);
                if (mounted && account != null) details.load();
                return;
              }
              await openProxySettings(context, widget.store);
              if (mounted) details.load();
            }
          : null,
      autofocus: autofocus,
    );
  }

  EpisodeScope _resolveEpisodeScope(DramaDetails details) =>
      resolveDetailEpisodeScope(
        details,
        routeDramaId: _routeDramaId,
        selectedRoute: _selectedRoute,
        routeGroup: _routeGroup,
      );

  void _selectRoute(EpisodeRoute route, int? currentIndex) {
    final pos = currentIndex == null
        ? -1
        : route.entries.indexWhere((item) => item.index == currentIndex);
    setState(() {
      _routeDramaId = _details!.drama.id;
      _selectedRoute = route.name;
      _routeGroup = pos >= 0 ? pos ~/ episodeGroupSize : 0;
    });
  }

  void _selectGroup(DramaDetails details, EpisodeScope scope, int group) {
    if (scope.routes.isNotEmpty) {
      if (group == scope.group || group < 0 || group >= scope.groupCount) {
        return;
      }
      setState(() {
        _routeDramaId = details.drama.id;
        _selectedRoute = scope.routeName;
        _routeGroup = group;
      });
      return;
    }
    details.selectGroup(group);
  }

  String _scopeGroupLabel(DramaDetails details, EpisodeScope scope, int group) {
    if (scope.routes.isEmpty) {
      return details.groupLabel(group);
    }
    final active = scope.routes.firstWhere(
      (route) => route.name == scope.routeName,
    );
    final start = group * episodeGroupSize;
    final end = (start + episodeGroupSize).clamp(0, active.entries.length) - 1;
    return '${start + 1}-${end + 1}';
  }

  Widget _routeChip(
    DetailMetrics m,
    EpisodeRoute route, {
    required bool selected,
    required int? currentIndex,
  }) => _GroupChip(
    label: route.name,
    selected: selected,
    metrics: m,
    onPressed: () => _selectRoute(route, currentIndex),
  );

  Widget _episodeTitle(
    DramaDetails details,
    DetailMetrics m, {
    EpisodeScope? scope,
  }) {
    final current = details.currentIndex;
    final activeRoute = scope != null && scope.routes.isNotEmpty
        ? scope.routes.firstWhere((route) => route.name == scope.routeName)
        : null;
    final isNetdisk = activeRoute != null
        ? activeRoute.entries.any((e) => isNetdiskEpisode(e.episode))
        : details.episodes.any(isNetdiskEpisode);
    final unit = isNetdisk ? '个文件' : '集';
    final summary = [
      if (activeRoute != null && scope!.routes.length > 1)
        '${activeRoute.entries.length} $unit · ${scope.routes.length} 条线路'
      else if (activeRoute != null)
        '${activeRoute.entries.length} $unit'
      else
        '${details.episodes.length} $unit',
      if (current != null && !isNetdisk)
        '当前第 ${details.episodes[current].number} 集',
    ].join(' · ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选集',
          style: TextStyle(fontSize: m.section, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: m.summary,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _episodeHeader(
    DramaDetails details,
    DetailMetrics m, {
    EpisodeScope? scope,
  }) => Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: _episodeTitle(details, m, scope: scope),
        ),
      ),
      if (details.currentIndex case final current?)
        TextButton(
          onPressed: () => _locate(current),
          child: const Text('定位当前'),
        ),
    ],
  );

  Widget _seasonRow(DramaDetails details, DetailMetrics m) => SeasonStrip(
    seasons: details.seasons,
    current: details.drama.id,
    store: widget.store,
    metaSize: m.meta,
    tagSize: m.tag,
    sectionSize: m.section,
    currentStatus: '正在浏览',
    collapsed: AppScope.formFactorOf(context) == FormFactor.window,
    onSelected: (season) => unawaited(_selectSeason(season)),
  );

  Future<void> _selectSeason(DramaSeason season) async {
    final details = _details!;
    if (season.drama.id == details.drama.id) return;
    _handle?.dispose();
    _handle = null;
    await details.selectSeason(season);
  }

  Widget _groupChip(
    DramaDetails details,
    DetailMetrics m,
    int group, {
    EpisodeScope? scope,
  }) => _GroupChip(
    key: _groupKey(group),
    label: scope == null
        ? details.groupLabel(group)
        : _scopeGroupLabel(details, scope, group),
    selected: group == (scope?.group ?? details.group),
    metrics: m,
    onPressed: () {
      if (scope != null) {
        _selectGroup(details, scope, group);
      } else {
        details.selectGroup(group);
      }
    },
  );

  Widget _swipeGroups(
    DramaDetails details,
    DetailMetrics m, {
    EpisodeScope? scope,
  }) {
    return SwipeSwitch(
      index: scope?.group ?? details.group,
      count: scope?.groupCount ?? details.groupCount,
      onSwitch: (group) => _swipeTo(details, group, scope: scope),
      child: _grid(details, m, scope: scope),
    );
  }

  void _renewKeys(String drama) {
    if (drama == _keyedDrama) return;
    _keyedDrama = drama;
    _currentEpisode = GlobalKey();
    _groupKeys.clear();
  }

  GlobalKey _groupKey(int group) {
    while (_groupKeys.length <= group) {
      _groupKeys.add(GlobalKey());
    }
    return _groupKeys[group];
  }

  void _swipeTo(DramaDetails details, int group, {EpisodeScope? scope}) {
    if (scope != null) {
      _selectGroup(details, scope, group);
    } else {
      details.selectGroup(group);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _groupKey(group).currentContext;
      if (chip == null || !chip.mounted) return;
      final position = Scrollable.maybeOf(
        chip,
        axis: Axis.horizontal,
      )?.position;
      final box = chip.findRenderObject();
      if (position == null || box == null) return;
      unawaited(
        position.ensureVisible(
          box,
          alignment: .5,
          duration: Motion.of(chip, Motion.medium),
          curve: Motion.standard,
        ),
      );
    });
  }

  Widget _grid(DramaDetails details, DetailMetrics m, {EpisodeScope? scope}) {
    final current = details.currentIndex;
    final entries =
        scope?.entries ??
        [
          for (final (offset, episode) in details.groupEpisodes.indexed)
            (
              episode: episode,
              index: details.group * episodeGroupSize + offset,
              label: compactEpisodeLabel(episode.title, episode.number),
            ),
        ];
    final descriptive = entries.any(
      (entry) =>
          isNetdiskEpisode(entry.episode) ||
          entry.label.length > 4 ||
          isDescriptiveEpisodeLabel(entry.label, entry.episode.number),
    );
    final formFactor = AppScope.formFactorOf(context);
    final television = AppScope.of(context).television;
    final extent = descriptive
        ? math.max(
            television ? 64.0 : 54.0,
            MediaQuery.textScalerOf(context).scale(m.cellText) * 2 + 22,
          )
        : math.max(
            m.cell,
            MediaQuery.textScalerOf(context).scale(m.cellText) + 28,
          );
    Widget cell(int offset) {
      final entry = entries[offset];
      final index = entry.index;
      final episode = entry.episode;
      return _EpisodeCell(
        key: index == current
            ? _currentEpisode
            : ValueKey('episode-$index-${episode.number}'),
        episode: episode,
        label: entry.label,
        descriptive: descriptive,
        metrics: m,
        current: index == current,
        watched: current != null && index < current,
        onPressed: () => _play(index),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = descriptive
            ? (formFactor == FormFactor.phone
                  ? 2
                  : math.max(
                      2,
                      ((constraints.maxWidth + m.cellGap) /
                              ((television ? 210.0 : 168.0) + m.cellGap))
                          .floor(),
                    ))
            : m.columnsFor(constraints.maxWidth);
        final fade = Motion.of(context, Motion.medium);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: fade == Duration.zero ? 1 : 0, end: 1),
          duration: fade,
          curve: Motion.standard,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            spacing: m.cellGap,
            children: [
              for (var row = 0; row < entries.length; row += columns)
                SizedBox(
                  height: extent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: m.cellGap,
                    children: [
                      for (var offset = row; offset < row + columns; offset++)
                        Expanded(
                          child: offset < entries.length
                              ? cell(offset)
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    super.key,
    required this.label,
    required this.selected,
    required this.metrics,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final DetailMetrics metrics;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final m = metrics;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(m.chipRadius),
    );
    final padding = EdgeInsets.symmetric(horizontal: m.chipPadding);
    final size = Size(0, m.chip);
    return FocusRing(
      radius: m.chipRadius,
      child: selected
          ? FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: shape,
                padding: padding,
                minimumSize: size,
                textStyle: TextStyle(
                  fontSize: m.chipText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                padding: padding,
                minimumSize: size,
                foregroundColor: colors.onSurfaceVariant,
                side: BorderSide(color: colors.outlineVariant),
                textStyle: TextStyle(fontSize: m.chipText),
              ),
              child: Text(label),
            ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    super.key,
    required this.episode,
    required this.label,
    required this.descriptive,
    required this.metrics,
    required this.current,
    required this.watched,
    required this.onPressed,
  });
  final Episode episode;
  final String label;
  final bool descriptive;
  final DetailMetrics metrics;
  final bool current;
  final bool watched;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(metrics.cellRadius);
    return FocusRing(
      radius: metrics.cellRadius,
      child: Semantics(
        button: true,
        label: '$label${episode.vip ? '，VIP' : ''}',
        excludeSemantics: true,
        child: Material(
          color: current ? colors.primaryContainer : colors.surfaceContainer,
          borderRadius: radius,
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
                      vertical: descriptive ? 6 : 2,
                    ),
                    child: Text(
                      label,
                      maxLines: descriptive ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: descriptive
                            ? math.max(12, metrics.cellText - 1.5)
                            : metrics.cellText,
                        fontWeight: current
                            ? FontWeight.w800
                            : watched
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: current
                            ? colors.onPrimaryContainer
                            : watched
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ),
                ),
                if (current)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _NowPlayingBars(color: colors.primary),
                  ),
                if (episode.vip)
                  Positioned(
                    right: 5,
                    top: 4,
                    child: Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: metrics.cellText - 7,
                        fontWeight: FontWeight.w800,
                        color: dark ? vipGold : const Color(0xFFB08200),
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

class _NowPlayingBars extends StatefulWidget {
  const _NowPlayingBars({required this.color});
  final Color color;

  @override
  State<_NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<_NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value * math.pi * 2;
      double h(double phase) => 4 + 6 * (0.5 + 0.5 * math.sin(t + phase));
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2,
        children: [
          for (final phase in const [0.0, 1.8, 3.4])
            Container(
              width: 2.5,
              height: h(phase),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      );
    },
  );
}

class _DescriptionDialog extends StatefulWidget {
  const _DescriptionDialog({required this.drama});
  final Drama drama;

  @override
  State<_DescriptionDialog> createState() => _DescriptionDialogState();
}

class _DescriptionDialogState extends State<_DescriptionDialog> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -120.0,
      LogicalKeyboardKey.arrowDown => 120.0,
      _ => null,
    };
    if (event is KeyUpEvent || step == null) return KeyEventResult.ignored;
    if (_scroll.hasClients) {
      final position = _scroll.position;
      _scroll.animateTo(
        (position.pixels + step).clamp(0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) => _onKey(event),
    child: AlertDialog(
      title: Text(widget.drama.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            controller: _scroll,
            child: Text(
              widget.drama.description,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ),
        ),
      ),
      actions: [
        FocusRing(
          radius: 20,
          child: TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ),
      ],
    ),
  );
}
