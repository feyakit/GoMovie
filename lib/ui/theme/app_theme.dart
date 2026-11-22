import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme_color.dart';
import 'motion.dart';
import 'palette.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static const crimson = GoPalette.brand;
  static const gold = GoPalette.amber;
  static const brandGradient = GoPalette.brandGradient;

  /// 品牌渐变必须跟着当前主题色走，否则换主题色后图标/角标还是红金。
  static LinearGradient gradientFor(ColorScheme scheme) => LinearGradient(
    colors: [
      scheme.primary,
      Color.lerp(scheme.primary, scheme.tertiary, 0.65)!,
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeMode mode(String preference) => switch (preference) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static SystemUiOverlayStyle systemBars(Brightness brightness) {
    final icons = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      statusBarBrightness: brightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData build(
    Color seed,
    Brightness brightness, {
    required bool television,
    bool pureBlack = false,
  }) {
    final scheme = _scheme(seed, brightness, pureBlack: pureBlack);
    final goColors = brightness == Brightness.dark
        ? GoColors.dark
        : GoColors.light;
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [goColors],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _type(scheme, television: television),
      pageTransitionsTheme: pageTransitions(television: television),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemBars(brightness),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      // ---- 以下为「所有控件统一品牌风格」：规格来自 tokens.dart，页面里不要再写死 ----
      filledButtonTheme: FilledButtonThemeData(
        style: _filled(
          scheme,
          background: scheme.primary,
          foreground: scheme.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _filled(
          scheme,
          background: scheme.primary,
          foreground: scheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlined(scheme)),
      textButtonTheme: TextButtonThemeData(style: _text(scheme)),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(Sizes.button, Sizes.button),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? scheme.onSurface.withValues(alpha: 0.10)
                : null,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelPadding: EdgeInsets.zero,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        disabledColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelStyle: TextStyle(
          fontSize: TypeScale.body,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: TypeScale.body,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          fontSize: TypeScale.body,
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        horizontalTitleGap: 14,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontSize: TypeScale.title,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: TypeScale.label,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        textStyle: TextStyle(
          fontSize: TypeScale.title,
          color: scheme.onSurface,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: TextStyle(
          fontSize: TypeScale.label,
          color: scheme.onSurface,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontSize: TypeScale.title,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: TypeScale.title,
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Sizes.chip)),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: TypeScale.body, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.16),
        trackHeight: 4,
      ),
    );
    final titled = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return theme.textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
    );
    return television ? _television(titled) : titled;
  }

  static bool _brandSeed(Color seed) {
    final value = seed.toARGB32();
    return value == ThemeColor.crimson.seed ||
        value == 0xFFFF2E54 ||
        value == GoPalette.brand.toARGB32();
  }

  static ColorScheme _scheme(
    Color seed,
    Brightness brightness, {
    required bool pureBlack,
  }) {
    final brand = _brandSeed(seed);
    final primary = brand ? GoPalette.brand : seed;
    final seeded = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );
    if (brightness == Brightness.dark) {
      return seeded.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        tertiary: GoPalette.amber,
        onTertiary: const Color(0xFF2A1C06),
        tertiaryContainer: const Color(0xFF3A2E1C),
        onTertiaryContainer: const Color(0xFFFFE3B8),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
        errorContainer: GoPalette.danger,
        onErrorContainer: GoPalette.dangerInk,
        surface: pureBlack ? Colors.black : GoPalette.canvas,
        onSurface: GoPalette.ink,
        onSurfaceVariant: GoPalette.muted,
        outline: const Color(0xFF3A3B44),
        outlineVariant: GoPalette.line,
        surfaceTint: primary,
        surfaceDim: pureBlack ? Colors.black : const Color(0xFF090A0D),
        surfaceBright: const Color(0xFF2C2D34),
        surfaceContainerLowest: pureBlack
            ? Colors.black
            : const Color(0xFF090A0D),
        surfaceContainerLow: pureBlack
            ? const Color(0xFF0B0B0B)
            : const Color(0xFF121318),
        surfaceContainer: pureBlack
            ? const Color(0xFF121212)
            : GoPalette.surface,
        surfaceContainerHigh: pureBlack
            ? const Color(0xFF1A1A1A)
            : const Color(0xFF1E1F25),
        surfaceContainerHighest: pureBlack
            ? const Color(0xFF242424)
            : GoPalette.raised,
      );
    }
    return seeded.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      tertiary: GoPalette.amber,
      onTertiary: const Color(0xFF2A1C06),
      error: GoPalette.lightDanger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: GoPalette.lightDanger,
      surface: GoPalette.paper,
      onSurface: GoPalette.paperInk,
      onSurfaceVariant: GoPalette.paperMuted,
      outline: const Color(0xFFD5CFC4),
      outlineVariant: const Color(0xFFE4DDD2),
      surfaceTint: primary,
      surfaceDim: const Color(0xFFE7E1D6),
      surfaceBright: GoPalette.paperSurface,
      surfaceContainerLowest: const Color(0xFFFFFCF8),
      surfaceContainerLow: GoPalette.paperSurface,
      surfaceContainer: const Color(0xFFF3EEE6),
      surfaceContainerHigh: const Color(0xFFEDE7DD),
      surfaceContainerHighest: GoPalette.paperRaised,
    );
  }

  static TextTheme _type(ColorScheme scheme, {required bool television}) {
    TextStyle style(
      double size,
      FontWeight weight, {
      Color? color,
      double height = 1.35,
    }) => TextStyle(
      fontSize: television ? size + 4 : size,
      fontWeight: weight,
      color: color ?? scheme.onSurface,
      height: height,
      letterSpacing: 0,
    );
    return TextTheme(
      displaySmall: style(TypeScale.display, FontWeight.w800, height: 1.15),
      headlineMedium: style(TypeScale.heading, FontWeight.w800, height: 1.2),
      headlineSmall: style(TypeScale.heading, FontWeight.w700, height: 1.25),
      titleLarge: style(20, FontWeight.w700),
      titleMedium: style(TypeScale.title, FontWeight.w700),
      titleSmall: style(TypeScale.body, FontWeight.w600),
      bodyLarge: style(TypeScale.title, FontWeight.w500, height: 1.45),
      bodyMedium: style(TypeScale.body, FontWeight.w400, height: 1.45),
      bodySmall: style(
        TypeScale.label,
        FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: style(TypeScale.body, FontWeight.w600),
      labelMedium: style(
        TypeScale.label,
        FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: style(
        TypeScale.caption,
        FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  static ButtonStyle _filled(
    ColorScheme scheme, {
    required Color background,
    required Color foreground,
  }) => FilledButton.styleFrom(
    minimumSize: const Size(0, Sizes.button),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    backgroundColor: background,
    foregroundColor: foreground,
    textStyle: const TextStyle(
      fontSize: TypeScale.title,
      fontWeight: FontWeight.w700,
    ),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    ),
  );

  static ButtonStyle _outlined(ColorScheme scheme) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, Sizes.button),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    foregroundColor: scheme.onSurface,
    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
    textStyle: const TextStyle(
      fontSize: TypeScale.title,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    ),
  );

  static ButtonStyle _text(ColorScheme scheme) => TextButton.styleFrom(
    minimumSize: const Size(0, Sizes.button),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    foregroundColor: scheme.onSurface,
    textStyle: const TextStyle(
      fontSize: TypeScale.title,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
    ),
  );

  static ThemeData _television(ThemeData theme) {
    final colors = theme.colorScheme;
    final button = ButtonStyle(
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.focused)
            ? colors.onSurface.withValues(alpha: 0.12)
            : null,
      ),
      minimumSize: const WidgetStatePropertyAll(Size(52, 48)),
    );
    return theme.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      focusColor: colors.primary.withValues(alpha: 0.16),
      iconButtonTheme: IconButtonThemeData(style: button),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
    );
  }
}
