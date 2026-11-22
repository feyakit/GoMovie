import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../download_converter.dart';
import '../../merge_queue.dart';
import '../../download_overview.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../detail/detail_page.dart';
import '../downloads/downloads_page.dart';
import '../history/history_page.dart';
import '../modules/modules_page.dart';
import '../netdisk/netdisk_page.dart';
import '../shell/app_shell.dart';
import '../settings/settings_page.dart';
import '../settings/settings_sections.dart';
import '../widgets/drama_tile.dart';
import '../widgets/focus_ring.dart';
import '../widgets/page_header.dart';
import '../widgets/group_card.dart';

class MinePage extends StatelessWidget {
  const MinePage({
    super.key,
    required this.store,
    required this.downloads,
    required this.converter,
    required this.merges,
    required this.entryFocus,
    required this.onExitUp,
  });
  final LocalStore store;
  final DownloadOverview downloads;
  final DownloadConverter converter;
  final MergeQueue merges;
  final FocusNode entryFocus;
  final VoidCallback onExitUp;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => switch (AppScope.formFactorOf(context)) {
          FormFactor.phone => _phone(context),
          FormFactor.pad || FormFactor.window => _wide(context),
          FormFactor.television => _television(context),
        },
      ),
    ),
  );

  void _openHistory(BuildContext context) =>
      openPage<void>(context, (_) => HistoryPage(store: store));

  void _openDownloads(BuildContext context) => openPage<void>(
    context,
    (_) => DownloadsPage(
      store: store,
      downloads: downloads,
      converter: converter,
      merges: merges,
    ),
  );

  void _openModules(BuildContext context) =>
      openPage<void>(context, (_) => ModulesPage(store: store));

  void _openNetdisk(BuildContext context) =>
      openPage<void>(context, (_) => NetdiskPage(store: store));

  void _openSettings(
    BuildContext context, {
    SettingsGroup group = SettingsGroup.playback,
  }) => openPage<void>(
    context,
    (_) => SettingsPage(store: store, initialGroup: group),
  );

  Widget _entries(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget row({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, size: 22, color: colors.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );

    final items = <Widget>[
      row(
        icon: Icons.cloud_done_outlined,
        title: '网盘与订阅',
        subtitle: '夸克网盘 · 饭太硬 / TVBox',
        onTap: () => _openNetdisk(context),
      ),
      if (!store.historyTab)
        row(
          icon: Icons.history_rounded,
          title: '观看历史',
          onTap: () => _openHistory(context),
        ),
      if (store.canDownload)
        row(
          icon: Icons.download_for_offline_outlined,
          title: '离线下载',
          onTap: () => _openDownloads(context),
        ),
      if (store.profile.admin)
        row(
          icon: Icons.extension_outlined,
          title: '站源模块',
          onTap: () => _openModules(context),
        ),
      row(
        icon: Icons.tune_rounded,
        title: '设置',
        subtitle: '界面、播放、代理与关于',
        onTap: () => _openSettings(context, group: SettingsGroup.appearance),
      ),
    ];

    return GroupCard(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(indent: 52, endIndent: 16, height: 1),
          items[i],
        ],
      ],
    );
  }

  Widget _poster(
    BuildContext context,
    WatchEntry entry,
    double width, {
    FocusNode? focusNode,
  }) {
    final drama = entry.drama;
    final total = drama.episodes;
    return ProgressPoster(
      drama: drama,
      width: width,
      focusNode: focusNode,
      progress: total > 0 ? entry.episode / total : 0,
      caption: total > 0 && entry.episode >= total && entry.finished
          ? '已看完'
          : '看到第 ${entry.episode} 集',
      tag: SourceSite.byId(drama.source).name,
      onTap: () => openPage<void>(
        context,
        (_) => DetailPage(store: store, drama: drama),
      ),
    );
  }

  Widget _phone(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      const PageHeader(title: '我的'),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _entries(context),
      ),
    ],
  );

  Widget _wide(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const PageHeader(title: '我的'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _entries(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _television(BuildContext context) {
    const columns = 7;
    const gap = 20.0;
    const padding = EdgeInsets.fromLTRB(
      televisionInset,
      14,
      televisionInset,
      27,
    );
    final history = store.history;
    final recent = history.take(columns - 1).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile =
            (constraints.maxWidth - padding.horizontal - gap * (columns - 1)) /
            columns;
        final page = SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 22,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text(
                        '最近观看',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (recent.isEmpty)
                      const _EmptyHistory(height: 200)
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: gap,
                        children: [
                          for (final (index, entry) in recent.indexed)
                            _poster(
                              context,
                              entry,
                              tile,
                              focusNode: index == 0 ? entryFocus : null,
                            ),
                          SizedBox(
                            width: tile,
                            child: _AllHistoryTile(
                              count: history.length,
                              onTap: () => _openHistory(context),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Row(
                  spacing: 20,
                  children: [
                    Expanded(
                      child: _TelevisionEntry(
                        icon: Icons.person_rounded,
                        primary: true,
                        focusNode: recent.isEmpty ? entryFocus : null,
                        title: store.profile.name,
                        subtitle:
                            '${store.profile.admin ? '管理员' : '普通用户'} · 切换用户',
                        onTap: () => openUsers(context, store),
                      ),
                    ),
                    Expanded(
                      child: _TelevisionEntry(
                        icon: Icons.cloud_done_outlined,
                        title: '网盘与订阅',
                        subtitle: '夸克网盘 · TVBox 订阅',
                        onTap: () => _openNetdisk(context),
                      ),
                    ),
                    if (store.profile.admin)
                      Expanded(
                        child: _TelevisionEntry(
                          icon: Icons.extension_outlined,
                          title: '模块',
                          subtitle: '安装与管理站源模块',
                          onTap: () => _openModules(context),
                        ),
                      ),
                    Expanded(
                      child: _TelevisionEntry(
                        icon: Icons.tune_rounded,
                        title: '设置',
                        subtitle: '外观、播放、站源与网络',
                        onTap: () => _openSettings(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is KeyUpEvent ||
                event.logicalKey != LogicalKeyboardKey.arrowUp) {
              return KeyEventResult.ignored;
            }
            final moved = FocusManager.instance.primaryFocus?.focusInDirection(
              TraversalDirection.up,
            );
            if (moved != true) onExitUp();
            return KeyEventResult.handled;
          },
          child: page,
        );
      },
    );
  }

}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.store, required this.onTap});
  final LocalStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = store.profile;
    return FocusRing(
      radius: 20,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 26,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${profile.admin ? '管理员' : '普通用户'} · 轻点切换用户',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllHistoryTile extends StatelessWidget {
  const _AllHistoryTile({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusRing(
      radius: 12,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '全部',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count 部',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
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

class _TelevisionEntry extends StatelessWidget {
  const _TelevisionEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.focusNode,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusRing(
      radius: 20,
      scale: 1,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: focusNode,
          focusColor: Colors.transparent,
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                spacing: 16,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary
                          ? colors.primaryContainer
                          : colors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: primary ? 26 : 24,
                      color: primary
                          ? colors.onPrimaryContainer
                          : colors.onSecondaryContainer,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Icon(Icons.history_rounded, size: 32, color: colors.onSurfaceVariant),
          Text(
            '还没有观看记录',
            style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
