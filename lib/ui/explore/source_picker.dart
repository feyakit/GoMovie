import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../widgets/choice_panel.dart';

/// 站源选择面板：按 group 分段（全部 / 内置 / 饭太硬 / 网盘），
/// 订阅源多起来以后一屏塞不下，分段 + 搜索比翻两屏快。
class SourcePicker extends StatefulWidget {
  const SourcePicker({super.key, required this.store});

  final LocalStore store;

  /// 返回选中的站源 id，点「管理站源」返回 [manageSourceId]。
  static Future<String?> show(BuildContext context, LocalStore store) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SourcePicker(store: store),
      );

  static const manageSourceId = '__manage__';

  @override
  State<SourcePicker> createState() => _SourcePickerState();
}

class _SourcePickerState extends State<SourcePicker> {
  late String _bucket;
  bool _searching = false;
  final _query = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _bucket = _initialBucket();
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  LocalStore get _store => widget.store;

  String _initialBucket() {
    final saved = _store.sourceGroup;
    if (saved.isEmpty) return '';
    for (final group in _groups()) {
      if (group.key == saved) return saved;
    }
    return '';
  }

  static String _bucketOf(SourceSite site) => switch (site.group) {
    'tvbox' => 'tvbox',
    'netdisk' => 'netdisk',
    _ => 'builtin',
  };

  List<_Group> _groups() {
    final counts = <String, int>{'': 0, 'builtin': 0, 'tvbox': 0, 'netdisk': 0};
    for (final site in _store.sources) {
      counts[''] = (counts[''] ?? 0) + 1;
      final key = _bucketOf(site);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return [
      _Group('', '全部', counts[''] ?? 0),
      _Group('builtin', '内置', counts['builtin'] ?? 0),
      _Group('tvbox', _tvboxLabel(), counts['tvbox'] ?? 0),
      _Group('netdisk', '网盘', counts['netdisk'] ?? 0),
    ];
  }

  /// 订阅源的组名来自后端（饭太硬订阅），取不到就退回「订阅」。
  String _tvboxLabel() {
    for (final site in _store.sources) {
      if (site.group == 'tvbox' && site.groupLabel.isNotEmpty) {
        final label = site.groupLabel.trim();
        return label.length > 6 ? '订阅' : label;
      }
    }
    return '订阅';
  }

  List<SourceSite> _visible() {
    final query = _query.text.trim().toLowerCase();
    return [
      for (final site in _store.sources)
        if (_bucket.isEmpty || _bucketOf(site) == _bucket)
          if (query.isEmpty || site.name.toLowerCase().contains(query)) site,
    ];
  }

  void _choose(String id) => Navigator.of(context).pop(id);

  void _selectBucket(String key) {
    setState(() => _bucket = key);
    _store.setSourceGroup(key).catchError((Object _) {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groups = _groups();
    final items = _visible();
    final current = _store.source;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '选择站点',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '长按设直连 / 代理 · 共 ${items.length} 个',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (_store.profile.admin)
                        Positioned(
                          left: 0,
                          child: IconButton(
                            tooltip: '管理站源',
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(SourcePicker.manageSourceId),
                            icon: const Icon(Icons.tune_rounded, size: 20),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          tooltip: _searching ? '收起搜索' : '搜索站点',
                          onPressed: () {
                            setState(() {
                              _searching = !_searching;
                              if (!_searching) _query.clear();
                            });
                          },
                          icon: Icon(
                            _searching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      hintText: '搜索站源名称…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (groups.where((g) => g.key.isEmpty || g.count > 0).length > 2)
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final group in groups)
                        if (group.key.isEmpty || group.count > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text('${group.label} ${group.count}'),
                              selected: _bucket == group.key,
                              onSelected: (_) => _selectBucket(group.key),
                            ),
                          ),
                    ],
                  ),
                ),
              Flexible(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          '没有匹配的站源',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 46,
                            ),
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final site = items[index];
                          return _SourceChip(
                            site: site,
                            selected: site.id == current,
                            networkMode: _store.sourceNetworkMode(site.id),
                            onTap: () => _choose(site.id),
                            onPickNetwork: () => _pickNetworkMode(site),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickNetworkMode(SourceSite site) async {
    final current = _store.sourceNetworkMode(site.id);
    final selected = await showChoicePanel<String>(
      context: context,
      title: '${site.name} · 网络策略',
      options: const [
        ChoiceOption('follow', '跟随全局'),
        ChoiceOption('direct', '强制直连'),
        ChoiceOption('proxy', '强制代理'),
      ],
      selected: current,
      grid: ChoiceGrid.sources,
    );
    if (selected == null || selected == current || !mounted) return;
    try {
      final repo = AppScope.of(context).repository;
      await repo.setSourceNetworkMode(site.id, selected);
      await _store.setSourceNetworkMode(site.id, selected);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('设置网络策略失败：$error')),
      );
    }
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.site,
    required this.selected,
    required this.networkMode,
    required this.onTap,
    required this.onPickNetwork,
  });

  final SourceSite site;
  final bool selected;
  final String networkMode;
  final VoidCallback onTap;
  final VoidCallback onPickNetwork;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final netLabel = switch (networkMode) {
      'direct' => '直连',
      'proxy' => '代理',
      _ => '',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      onLongPress: onPickNetwork,
      onSecondaryTap: onPickNetwork,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.16)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.7)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                site.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ),
            if (netLabel.isNotEmpty) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  netLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: colors.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group(this.key, this.label, this.count);
  final String key;
  final String label;
  final int count;
}
