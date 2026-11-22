import 'package:flutter/material.dart';

import '../app_scope.dart';

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF16161B) : scheme.surfaceContainerHigh;
    final highlight = dark
        ? const Color(0xFF25252E)
        : scheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, -0.3),
              end: Alignment(t + 1, 0.3),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

class ExploreSkeleton extends StatelessWidget {
  const ExploreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final factor = AppScope.formFactorOf(context);
    final columns = switch (factor) {
      FormFactor.phone => 3,
      FormFactor.pad => 4,
      FormFactor.window => 5,
      FormFactor.television => 5,
    };
    final inset = factor == FormFactor.phone ? 16.0 : 24.0;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
      children: [
        ShimmerBox(
          height: factor == FormFactor.phone ? 186 : 220,
          radius: factor == FormFactor.phone ? 20 : 24,
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: columns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (context, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ShimmerBox(radius: 12)),
              SizedBox(height: 8),
              ShimmerBox(height: 14, radius: 6),
              SizedBox(height: 6),
              ShimmerBox(width: 72, height: 11, radius: 5),
            ],
          ),
        ),
      ],
    );
  }
}
