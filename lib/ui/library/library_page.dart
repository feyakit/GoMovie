import 'package:flutter/material.dart';

import '../../download_converter.dart';
import '../../download_overview.dart';
import '../../local_store.dart';
import '../../merge_queue.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../detail/detail_page.dart';
import '../downloads/downloads_page.dart';
import '../follow/follow_page.dart';
import '../history/history_page.dart';
import '../shell/app_shell.dart';
import '../theme/palette.dart';
import '../widgets/cover_image.dart';
import '../widgets/focus_ring.dart';
import '../widgets/page_header.dart';
import '../widgets/status_view.dart';

enum LibrarySection { resume, follow, history, downloads }

class LibraryPage extends StatefulWidget {
  const LibraryPage({
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
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  var _section = LibrarySection.resume;

  List<LibrarySection> _sections(bool history, bool downloads) => [
    LibrarySection.resume,
    LibrarySection.follow,
    if (history) LibrarySection.history,
    if (downloads) LibrarySection.downloads,
  ];

  @override
  Widget build(BuildContext context) {
    final television = AppScope.of(context).television;
    final downloads = widget.downloads.available && widget.store.canDownload;
    final sections = _sections(widget.store.historyTab, downloads);
    if (!sections.contains(_section)) _section = LibrarySection.resume;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: '片库'),
            _Segments(
              sections: sections,
              selected: _section,
              onSelected: (section) => setState(() => _section = section),
            ),
            Expanded(
              child: IndexedStack(
                index: sections.indexOf(_section),
                sizing: StackFit.expand,
                children: [
                  for (final section in sections)
                    switch (section) {
                      LibrarySection.resume => _ResumeList(store: widget.store),
                      LibrarySection.follow => FollowPage(
                        store: widget.store,
                        entryFocus: widget.entryFocus,
                        onExitUp: widget.onExitUp,
                        embedded: true,
                      ),
                      LibrarySection.history => HistoryPage(
                        store: widget.store,
                        root: true,
                        embedded: true,
                      ),
                      LibrarySection.downloads => _DownloadList(
                        store: widget.store,
                        downloads: widget.downloads,
                        converter: widget.converter,
                        merges: widget.merges,
                        television: television,
                      ),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });

  final List<LibrarySection> sections;
  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelected;

  String _label(LibrarySection section) => switch (section) {
    LibrarySection.resume => '继续看',
    LibrarySection.follow => '追剧',
    LibrarySection.history => '历史',
    LibrarySection.downloads => '下载',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: [
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FocusRing(
                radius: 999,
                scale: 1,
                child: ChoiceChip(
                  label: Text(_label(section)),
                  selected: section == selected,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(section),
                  selectedColor: colors.primary,
                  labelStyle: TextStyle(
                    color: section == selected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResumeList extends StatelessWidget {
  const _ResumeList({required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final entries = [
        for (final entry in store.history)
          if (!entry.finished) entry,
      ];
      if (entries.isEmpty) {
        return const StatusView(
          title: '还没有观看记录',
          message: '去发现或搜索挑一部，进度会留在这里。',
          icon: Icons.play_circle_outline_rounded,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ResumeRow(
          entry: entries[index],
          onTap: () => openPage<void>(
            context,
            (_) => DetailPage(store: store, drama: entries[index].drama),
          ),
        ),
      );
    },
  );
}

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.entry, required this.onTap});

  final WatchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = entry.drama.episodes;
    final progress = entry.duration > 1
        ? (entry.position / entry.duration).clamp(0.0, 1.0)
        : total > 0
        ? (entry.episode / total).clamp(0.0, 1.0)
        : 0.0;
    final site = SourceSite.byId(entry.drama.source).name;
    return FocusRing(
      radius: 18,
      scale: 1,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 96,
                    child: DramaCover(
                      drama: entry.drama,
                      radius: 12,
                      details: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        entry.drama.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '第 ${entry.episode} 集 · $site',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          color: colors.primary,
                          backgroundColor: colors.surfaceContainerHighest,
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
    );
  }
}

class _DownloadList extends StatelessWidget {
  const _DownloadList({
    required this.store,
    required this.downloads,
    required this.converter,
    required this.merges,
    required this.television,
  });

  final LocalStore store;
  final DownloadOverview downloads;
  final DownloadConverter converter;
  final MergeQueue merges;
  final bool television;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: downloads,
    builder: (context, _) {
      final jobs = downloads.jobs;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            '删除下载不会取消追剧。媒体身份与来源 ID 分开保存。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            const StatusView(
              title: '还没有下载',
              message: '在详情页选择集数后可以离线保存。',
              icon: Icons.download_outlined,
            )
          else
            for (final job in jobs) ...[
              _DownloadRow(job: job),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => openPage<void>(
              context,
              (_) => DownloadsPage(
                store: store,
                downloads: downloads,
                converter: converter,
                merges: merges,
              ),
            ),
            child: Text(television ? '查看下载' : '管理下载'),
          ),
        ],
      );
    },
  );
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final go = GoColors.of(context);
    final (Color bar, String label) = switch (job.state) {
      'completed' => (go.success, '已完成，可离线播放'),
      'failed' => (go.danger, job.error.isEmpty ? '下载失败' : job.error),
      'paused' => (go.warning, '已暂停'),
      'queued' => (go.warning, '等待网络'),
      'downloading' => (colors.primary, '下载中 ${(job.progress * 100).round()}%'),
      'converting' => (go.warning, '正在处理'),
      _ => (colors.onSurfaceVariant, job.stateLabel),
    };
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 74,
                child: DramaCover(drama: job.drama, radius: 12, details: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    job.drama.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '第 ${job.episode.number} 集 · ${SourceSite.byId(job.drama.source).name}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: job.completed ? 1 : job.progress.clamp(0, 1),
                      minHeight: 4,
                      color: bar,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: bar,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
