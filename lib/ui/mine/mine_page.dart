import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../modules/modules_page.dart';
import '../netdisk/netdisk_page.dart';
import '../explore/source_actions.dart';
import '../shell/app_shell.dart';
import '../settings/appearance_settings.dart';
import '../settings/settings_page.dart';
import '../widgets/brand_mark.dart';
import '../widgets/focus_ring.dart';
import '../widgets/page_header.dart';

class MinePage extends StatelessWidget {
  const MinePage({
    super.key,
    required this.store,
    required this.entryFocus,
    required this.onExitUp,
  });
  final LocalStore store;
  final FocusNode entryFocus;
  final VoidCallback onExitUp;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _manage(context),
      ),
    ),
  );

  Widget _manage(BuildContext context) {
    final television = AppScope.of(context).television;
    final page = ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        PageHeader(title: '管理', actions: const [BrandMark(size: 28)]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _Group(
                title: '站源与模块',
                children: [
                  _ManageRow(
                    title: '站源',
                    subtitle: store.sources.isEmpty
                        ? '还没有可用站源'
                        : '${store.sources.length} 个已启用 · 当前 ${SourceSite.byId(store.source).name}',
                    focusNode: entryFocus,
                    onTap: () => pickSource(context, store),
                  ),
                  _ManageRow(
                    title: '已安装模块',
                    subtitle: '装卸与开关',
                    onTap: () => _openModules(context),
                  ),
                ],
              ),
              _Group(
                title: '网盘与订阅',
                children: [
                  _ManageRow(
                    title: '夸克登录',
                    subtitle: '扫码，凭证留在本机',
                    onTap: () => _openNetdisk(context),
                  ),
                  _ManageRow(
                    title: 'TVBox / 饭太硬',
                    subtitle: '同步订阅',
                    onTap: () => _openNetdisk(context),
                  ),
                ],
              ),
              _Group(
                title: '网络与外观',
                children: [
                  _ManageRow(
                    title: '网络策略',
                    subtitle: '按站：跟随 / 直连 / 代理',
                    onTap: () => openProxySettings(context, store),
                  ),
                  _ManageRow(
                    title: '主题',
                    subtitle: '深色 / 浅色 / 跟随系统',
                    onTap: () => openPage<void>(
                      context,
                      (_) => Scaffold(
                        appBar: AppBar(title: const Text('主题')),
                        body: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [AppearanceSettings(store: store)],
                        ),
                      ),
                    ),
                  ),
                  _ManageRow(
                    title: '电视',
                    subtitle: '默认深色，不跟随壁纸取色',
                    onTap: () => openPage<void>(
                      context,
                      (_) => Scaffold(
                        appBar: AppBar(title: const Text('电视')),
                        body: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [AppearanceSettings(store: store)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _Group(
                title: '数据',
                children: [
                  _ManageRow(
                    title: '多用户与备份',
                    subtitle: '导出恢复，不提供云同步',
                    onTap: () => openUsers(context, store),
                  ),
                  _ManageRow(
                    title: '搜索历史',
                    subtitle: store.recentSearches.isEmpty ? '没有记录' : '可清空',
                    onTap: store.recentSearches.isEmpty
                        ? null
                        : () async {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: const Text('清空搜索历史？'),
                                content: const Text('只清除本机最近搜索，不删除观看记录。'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: const Text('清空'),
                                  ),
                                ],
                              ),
                            );
                            if (accepted == true) {
                              await store.clearRecentSearches();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (!television) return page;
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
  }

  void _openModules(BuildContext context) =>
      openPage<void>(context, (_) => ModulesPage(store: store));

  void _openNetdisk(BuildContext context) =>
      openPage<void>(context, (_) => NetdiskPage(store: store));
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Material(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) Divider(height: 1, color: colors.outlineVariant),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.focusNode,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusRing(
      radius: 0,
      scale: 1,
      child: ListTile(
        focusNode: focusNode,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
