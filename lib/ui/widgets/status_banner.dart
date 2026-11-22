import 'package:flutter/material.dart';

import '../theme/palette.dart';

enum StatusTone { success, warning, danger, neutral }

/// 状态必须配文字，不能只靠颜色。
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final StatusTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = GoColors.of(context);
    final (Color background, Color foreground) = switch (tone) {
      StatusTone.success => (colors.success, colors.onSuccess),
      StatusTone.warning => (colors.warning, colors.onWarning),
      StatusTone.danger => (colors.danger, colors.onDanger),
      StatusTone.neutral => (colors.raised, colors.ink),
    };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.92),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.tone, required this.label});

  final StatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = GoColors.of(context);
    final (Color background, Color foreground) = switch (tone) {
      StatusTone.success => (colors.success, colors.onSuccess),
      StatusTone.warning => (colors.warning, colors.onWarning),
      StatusTone.danger => (colors.danger, colors.onDanger),
      StatusTone.neutral => (colors.raised, colors.muted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
