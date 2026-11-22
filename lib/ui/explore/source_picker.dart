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
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  Text('全部站源', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} 个',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in groups)
                    if (group.key.isEmpty || group.count > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${group.label} ${group.count}'),
                          selected: _bucket == group.key,
                          onSelected: (_) => _selectBucket(group.key),
                        ),
                      ),
                ],
              ),
            ),
            if (_store.sources.length > 18)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索站源',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                  : SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final site in items)
                            _SourceChip(
                              site: site,
                              selected: site.id == current,
                              networkMode: _store.sourceNetworkMode(site.id),
                              onTap: () => _choose(site.id),
                              onPickNetwork: () => _pickNetworkMode(site),
                            ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text(
                '长按或右键站源可设直连 / 代理（开 TUN 全局 VPN 需配合规则分流）',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (_store.profile.admin)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(SourcePicker.manageSourceId),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('管理站源'),
                  ),
                ),
              ),
          ],
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
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('设置网络策略失败：$error')));
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.18)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              site.name,
              style: TextStyle(
                fontSize: 13,
                color: selected ? colors.primary : colors.onSurface,
              ),
            ),
            if (site.group == 'tvbox') ...[
              const SizedBox(width: 5),
              Text(
                'jar',
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
              ),
            ],
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
                    fontSize: 9,
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
