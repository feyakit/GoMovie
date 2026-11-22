import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomovie_app/models.dart';
import 'package:gomovie_app/ui/player/television_episode_panel.dart';
import 'package:gomovie_app/ui/theme/app_theme.dart';
import 'package:gomovie_app/ui/theme/palette.dart';
import 'package:gomovie_app/ui/widgets/phone_navigation_bar.dart';
import 'package:gomovie_app/ui/widgets/play_orb.dart';
import 'package:gomovie_app/ui/widgets/status_banner.dart';
import 'package:gomovie_app/ui/player/swipe_controls.dart';

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('graphite ink stays readable and status colors stay distinct', () {
    expect(
      _contrast(GoPalette.ink, GoPalette.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(GoPalette.muted, GoPalette.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(GoPalette.paperInk, GoPalette.paper),
      greaterThanOrEqualTo(4.5),
    );
    expect(GoPalette.brand, isNot(GoPalette.success));
    expect(GoPalette.brand, isNot(GoPalette.warning));
    expect(GoPalette.brand, isNot(GoPalette.danger));
  });

  test('horizontal seek yields the screen edge to the system', () {
    expect(seekGestureYieldsToSystem(8, 400), isTrue);
    expect(seekGestureYieldsToSystem(390, 400), isTrue);
    expect(seekGestureYieldsToSystem(80, 400), isFalse);
  });

  test('episode lines stay separate when counts differ', () {
    final choices = televisionEpisodeChoices([
      Episode(const {'title': '线路 1 · 1'}, 1),
      Episode(const {'title': '线路 1 · 2'}, 2),
      Episode(const {'title': '线路 2 · 1'}, 3),
    ]);
    expect(choices.map((item) => item.route).toSet(), {'线路 1', '线路 2'});
    expect(choices.where((item) => item.route == '线路 2'), hasLength(1));
  });

  testWidgets('phone chrome uses the graphite theme and four destinations', (
    tester,
  ) async {
    final theme = AppTheme.build(
      const Color(0xFFE23B4C),
      Brightness.dark,
      television: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              PlayOrb(onPressed: () {}),
              const StatusBanner(
                tone: StatusTone.warning,
                title: '需验证',
                message: '源B 需要完成人机验证后才能继续。',
              ),
              const StatusBanner(
                tone: StatusTone.danger,
                title: '部分失败',
                message: '已保留其它站的部分结果。',
              ),
              PhoneNavigationBar(
                destinations: const [
                  PhoneDestination(label: '发现'),
                  PhoneDestination(label: '搜索'),
                  PhoneDestination(label: '片库'),
                  PhoneDestination(label: '管理'),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(theme.colorScheme.surface, GoPalette.canvas);
    expect(theme.colorScheme.onSurface, GoPalette.ink);
    expect(theme.colorScheme.primary, GoPalette.brand);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('片库'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    expect(find.text('需验证'), findsOneWidget);
    expect(find.text('已保留其它站的部分结果。'), findsOneWidget);
    expect(tester.getSize(find.byType(PlayOrb)).shortestSide, greaterThan(40));
  });

  testWidgets('light theme uses warm paper instead of graphite', (
    tester,
  ) async {
    final theme = AppTheme.build(
      const Color(0xFFE23B4C),
      Brightness.light,
      television: false,
    );
    expect(theme.colorScheme.surface, GoPalette.paper);
    expect(theme.colorScheme.onSurface, GoPalette.paperInk);
    expect(theme.brightness, Brightness.light);
    await tester.pumpWidget(MaterialApp(theme: theme, home: const Scaffold()));
  });
}
