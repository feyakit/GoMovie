import 'package:flutter/material.dart';

class PlayerShade extends StatelessWidget {
  const PlayerShade({
    super.key,
    required this.height,
    required this.top,
    this.topAlpha = 0x8C,
    this.bottomAlpha = 0xA6,
  });

  final double height;
  final bool top;
  final int topAlpha;
  final int bottomAlpha;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Color.fromARGB(top ? topAlpha : bottomAlpha, 0, 0, 0),
            const Color(0x00000000),
          ],
        ),
      ),
    ),
  );
}

class PlayerBoostBadge extends StatelessWidget {
  const PlayerBoostBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        const Icon(Icons.fast_forward_rounded, size: 16, color: Colors.white),
        Text(
          '$label播放中',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class PlayerStreakBadge extends StatelessWidget {
  const PlayerStreakBadge({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final forward = streak > 0;
    return IgnorePointer(
      child: Align(
        alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 156,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: forward
                ? const BorderRadius.horizontal(left: Radius.circular(110))
                : const BorderRadius.horizontal(right: Radius.circular(110)),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(
                  forward
                      ? Icons.fast_forward_rounded
                      : Icons.fast_rewind_rounded,
                  size: 32,
                  color: Colors.white,
                ),
                Text(
                  '${forward ? '+' : '-'}${streak.abs() * 10} 秒',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
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

class PlayerRouteNoticeBadge extends StatelessWidget {
  const PlayerRouteNoticeBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
