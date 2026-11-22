import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomovie_app/models.dart';
import 'package:gomovie_app/ui/app_scope.dart';
import 'package:gomovie_app/ui/explore/explore_hero.dart';
import 'package:gomovie_app/ui/player/player_dock.dart';
import 'package:gomovie_app/ui/player/television_episode_panel.dart';
import 'package:gomovie_app/ui/shell/app_shell.dart';
import 'package:gomovie_app/ui/theme/app_theme.dart';
import 'package:gomovie_app/ui/theme/palette.dart';
import 'package:gomovie_app/ui/widgets/brand_mark.dart';
import 'package:gomovie_app/ui/widgets/phone_navigation_bar.dart';
import 'package:gomovie_app/ui/widgets/search_result_tile.dart';
import 'package:gomovie_app/ui/widgets/status_banner.dart';

import 'support/fakes.dart';

const _capture = bool.fromEnvironment('CAPTURE_SHOTS');

void main() {
  testWidgets('fixture screens render with a CJK font', (tester) async {
    if (!_capture) return;
    final fontFile = File(
      Platform.environment['SHOT_FONT'] ?? '/tmp/NotoSansSC-Regular.otf',
    );
    expect(fontFile.existsSync(), isTrue, reason: '缺少中文字体 ${fontFile.path}');
    stderr.writeln('shot: font ${fontFile.lengthSync()} bytes');
    await tester.runAsync(() async {
      final loader = FontLoader('ShotSans')
        ..addFont(
          Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
        );
      await loader.load().timeout(const Duration(seconds: 20));
    });
    stderr.writeln('shot: font loaded');
    final drama = Drama(
      id: 'fixture-tower',
      source: 'fixture',
      title: '守夜塔',
      episodes: 20,
      category: '电影',
      description: '夹具海报，不是站源内容。',
    );
    Future<void> shoot(
      String name,
      Widget page, {
      bool light = false,
      bool television = false,
    }) async {
      final boundaryKey = GlobalKey();
      stderr.writeln('shot: pump $name');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            GoPalette.brand,
            light ? Brightness.light : Brightness.dark,
            television: television,
          ),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(
                context,
              ).textTheme.apply(fontFamily: 'ShotSans'),
            ),
            child: child!,
          ),
          home: AppScope(
            repository: FakeRepository(),
            formFactor: television ? FormFactor.television : FormFactor.phone,
            child: ShellForeground(
              foreground: true,
              child: RepaintBoundary(key: boundaryKey, child: page),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      stderr.writeln('shot: toImage $name');
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      );
      if (image == null) {
        throw StateError('toImage returned null for $name');
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('/opt/cursor/artifacts/$name.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await shoot('phone-discover-dark', _Discover(drama: drama));
    await shoot('phone-discover-light', _Discover(drama: drama), light: true);
    await shoot('phone-search-states', _SearchStates(drama: drama));
    await shoot('phone-detail', _Detail(drama: drama));
    await shoot('phone-player-dock', const _Player());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await shoot('tv-home', _TvHome(drama: drama), television: true);
    await shoot('tv-player-panel', const _TvPanel(), television: true);
  });
}

class _Discover extends StatelessWidget {
  const _Discover({required this.drama});
  final Drama drama;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      children: [
        const Row(
          children: [
            BrandMark(size: 28),
            SizedBox(width: 8),
            Text(
              'GoMovie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Spacer(),
            Text('夹具渲染'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('继续观看', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        ExploreHero(
          drama: drama,
          kicker: '继续观看',
          meta: '第 7 集 · 还剩 18 分钟 · 夹具',
          action: '播放',
          progress: 0.42,
          onPlay: () {},
          onDetail: () {},
        ),
        const SizedBox(height: 20),
        const Text(
          '今日推荐',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '来自当前站源模块与本地记录，不是服务端猜你喜欢。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    bottomNavigationBar: PhoneNavigationBar(
      destinations: const [
        PhoneDestination(label: '发现'),
        PhoneDestination(label: '搜索'),
        PhoneDestination(label: '片库'),
        PhoneDestination(label: '管理'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
  );
}

class _SearchStates extends StatelessWidget {
  const _SearchStates({required this.drama});
  final Drama drama;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Text(
          '搜索',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text('按站源保留结果，同名不合并'),
        const SizedBox(height: 12),
        const StatusBanner(
          tone: StatusTone.warning,
          title: '需验证',
          message: '源B 需要完成人机验证后才能继续。不会跳过验证。',
          actionLabel: '去验证',
        ),
        const SizedBox(height: 8),
        const StatusBanner(
          tone: StatusTone.danger,
          title: '部分失败',
          message: '源A 暂时无响应。已保留其它站的部分结果。',
          actionLabel: '重试',
        ),
        const SizedBox(height: 12),
        SearchResultTile(drama: drama, onTap: () {}),
        const SizedBox(height: 8),
        SearchResultTile(
          drama: Drama(
            id: 'fixture-cut',
            source: 'other',
            title: '守夜塔',
            episodes: 1,
            badge: '导演剪辑',
          ),
          onTap: () {},
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.drama});
  final Drama drama;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        children: [
          const Text('返回'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 108,
                height: 152,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('夹具海报'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drama.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '夹具 · 20 集',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('播放第 7 集'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('简介（夹具）'),
          const SizedBox(height: 8),
          const Text('本段为占位说明，不对应真实作品。换线路集数不一致时不会自动跳集。'),
          const SizedBox(height: 16),
          const Text('线路', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: const [
              Chip(label: Text('线路 1 可播放')),
              Chip(label: Text('线路 2 播放中')),
              Chip(label: Text('线路 3 失败')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned(
          left: 16,
          top: 28,
          right: 16,
          child: Text(
            '守夜塔 · 第 7 集    夹具画面',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: PlayerDock(
              speedLabel: '1.0x',
              danmakuSupported: true,
              danmakuEnabled: true,
              onLock: null,
              onDanmaku: null,
              onRoutes: null,
              onEpisodes: null,
              onSpeed: null,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TvHome extends StatelessWidget {
  const _TvHome({required this.drama});
  final Drama drama;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        const SizedBox(
          width: 120,
          child: Column(
            children: [
              SizedBox(height: 24),
              BrandMark(size: 48),
              SizedBox(height: 24),
              Text(
                '发现',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text('搜索', style: TextStyle(fontSize: 22)),
              Text('片库', style: TextStyle(fontSize: 22)),
              Text('管理', style: TextStyle(fontSize: 22)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ExploreHero(
              drama: drama,
              kicker: '继续观看',
              meta: '第 7 集 · 夹具 · 焦点不放大',
              action: '播放',
              onPlay: () {},
              onDetail: () {},
            ),
          ),
        ),
      ],
    ),
  );
}

class _TvPanel extends StatelessWidget {
  const _TvPanel();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: TelevisionEpisodePanel(
      choices: televisionEpisodeChoices([
        Episode(const {'title': '线路 1 · 1'}, 1),
        Episode(const {'title': '线路 2 · 7'}, 7),
        Episode(const {'title': '线路 3 · 1'}, 8),
      ]),
      route: '线路 2',
      cursor: 0,
      onRoutes: false,
      mismatched: true,
    ),
  );
}
