import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static const crimson = Color(0xFFFF2E54);
  static const gold = Color(0xFFFF9E2C);
  static const brandGradient = LinearGradient(
    colors: [crimson, gold],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
    final seeded = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = switch ((brightness, pureBlack, seed.toARGB32())) {
      (Brightness.dark, true, _) => seeded.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0B0B0B),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF242424),
      ),
      (Brightness.dark, false, 0xFFFF2E54) => seeded.copyWith(
        primary: const Color(0xFFFF2E54),
        onPrimary: Colors.white,
        tertiary: const Color(0xFFFF9E2C),
        onTertiary: const Color(0xFF1A0E00),
        surface: const Color(0xFF0A0A0C),
        surfaceDim: const Color(0xFF070709),
        surfaceContainerLowest: const Color(0xFF0A0A0C),
        surfaceContainerLow: const Color(0xFF121216),
        surfaceContainer: const Color(0xFF16161B),
        surfaceContainerHigh: const Color(0xFF1E1E24),
        surfaceContainerHighest: const Color(0xFF27272F),
        outlineVariant: const Color(0xFF2B2B33),
      ),
      _ => seeded,
    };
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
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
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
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

  static ButtonStyle _filled(
    ColorScheme scheme, {
    required Color background,
    required Color foreground,
  }) => FilledButton.styleFrom(
    minimumSize: const Size(0, Sizes.button),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    backgroundColor: background,
    foregroundColor: foreground,
    textStyle: const TextStyle(
      fontSize: TypeScale.title,
      fontWeight: FontWeight.w700,
    ),
    elevation: 0,
    shape: const StadiumBorder(),
  );

  static ButtonStyle _outlined(ColorScheme scheme) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, Sizes.button),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    foregroundColor: scheme.onSurface,
    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
    textStyle: const TextStyle(
      fontSize: TypeScale.title,
      fontWeight: FontWeight.w600,
    ),
    shape: const StadiumBorder(),
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
      iconButtonTheme: IconButtonThemeData(
        style: button.merge(theme.iconButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.merge(theme.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.merge(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button.merge(theme.textButtonTheme.style),
      ),
    );
  }
}
