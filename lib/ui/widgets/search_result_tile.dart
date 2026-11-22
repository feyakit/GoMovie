import 'package:flutter/material.dart';

import '../../models.dart';
import 'cover_image.dart';
import 'focus_ring.dart';
import 'status_banner.dart';

/// 聚合结果按站源和 ID 分行，不把同名折成一条。
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.drama,
    required this.onTap,
    this.status,
    this.focusNode,
  });

  final Drama drama;
  final VoidCallback onTap;
  final ({StatusTone tone, String label})? status;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final site = SourceSite.byId(drama.source).name;
    final meta = drama.episodes > 0
        ? '$site · ${drama.episodes} 集'
        : [
            site,
            if (drama.category.isNotEmpty) drama.category,
            if (drama.badge.isNotEmpty) drama.badge,
          ].join(' · ');
    return FocusRing(
      radius: 18,
      scale: 1,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: focusNode,
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
                    child: DramaCover(drama: drama, radius: 12, details: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        drama.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (status case final status?)
                        StatusChip(tone: status.tone, label: status.label),
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
