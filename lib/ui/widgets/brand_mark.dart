import 'package:flutter/material.dart';

/// 仓库原始赤金折纸标识。像素来自 `scripts/brand_icon_master.png`，不要重绘。
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.semanticLabel = 'GoMovie'});

  final double size;
  final String semanticLabel;

  static const asset = 'scripts/brand_icon_master.png';

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    ),
  );
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 28, this.fontSize = 20});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: markSize),
      const SizedBox(width: 8),
      Text(
        'GoMovie',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}
