import 'package:flutter/material.dart';

/// 石墨底、暖白字、朱红强调。状态色独立于品牌色。
abstract final class GoPalette {
  static const canvas = Color(0xFF0D0E12);
  static const surface = Color(0xFF17181C);
  static const raised = Color(0xFF22232A);
  static const ink = Color(0xFFF4F1EA);
  static const muted = Color(0xFF9A9AA3);
  static const line = Color(0xFF2A2B32);

  static const paper = Color(0xFFF6F1E8);
  static const paperSurface = Color(0xFFFFFBF6);
  static const paperRaised = Color(0xFFE7E1D6);
  static const paperInk = Color(0xFF1C1B19);
  static const paperMuted = Color(0xFF6F6A63);

  static const brand = Color(0xFFE23B4C);
  static const brandDeep = Color(0xFFDC2E4A);
  static const brandHot = Color(0xFFFE4854);
  static const amber = Color(0xFFE8A63A);
  static const amberHot = Color(0xFFFFC341);

  static const success = Color(0xFF2C8A64);
  static const successInk = Color(0xFFD7F5E6);
  static const warning = Color(0xFFC26B16);
  static const warningInk = Color(0xFFFFE4C8);
  static const danger = Color(0xFF9E2B22);
  static const dangerHot = Color(0xFFFF2E54);
  static const dangerInk = Color(0xFFFFD9D4);

  static const lightSuccess = Color(0xFF1F7A56);
  static const lightWarning = Color(0xFF9A5410);
  static const lightDanger = Color(0xFF8E241C);

  static const brandGradient = LinearGradient(
    colors: [brand, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

@immutable
class GoColors extends ThemeExtension<GoColors> {
  const GoColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.brand,
    required this.amber,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
  });

  final Color canvas;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color brand;
  final Color amber;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;

  static const dark = GoColors(
    canvas: GoPalette.canvas,
    surface: GoPalette.surface,
    raised: GoPalette.raised,
    ink: GoPalette.ink,
    muted: GoPalette.muted,
    brand: GoPalette.brand,
    amber: GoPalette.amber,
    success: GoPalette.success,
    onSuccess: GoPalette.successInk,
    warning: GoPalette.warning,
    onWarning: GoPalette.warningInk,
    danger: GoPalette.danger,
    onDanger: GoPalette.dangerInk,
  );

  static const light = GoColors(
    canvas: GoPalette.paper,
    surface: GoPalette.paperSurface,
    raised: GoPalette.paperRaised,
    ink: GoPalette.paperInk,
    muted: GoPalette.paperMuted,
    brand: GoPalette.brand,
    amber: GoPalette.amber,
    success: GoPalette.lightSuccess,
    onSuccess: Color(0xFFF3FFF8),
    warning: GoPalette.lightWarning,
    onWarning: Color(0xFFFFF6EC),
    danger: GoPalette.lightDanger,
    onDanger: Color(0xFFFFF4F2),
  );

  static GoColors of(BuildContext context) =>
      Theme.of(context).extension<GoColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  GoColors copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? brand,
    Color? amber,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
  }) => GoColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    brand: brand ?? this.brand,
    amber: amber ?? this.amber,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
  );

  @override
  GoColors lerp(ThemeExtension<GoColors>? other, double t) {
    if (other is! GoColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GoColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      brand: mix(brand, other.brand),
      amber: mix(amber, other.amber),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      danger: mix(danger, other.danger),
      onDanger: mix(onDanger, other.onDanger),
    );
  }
}
