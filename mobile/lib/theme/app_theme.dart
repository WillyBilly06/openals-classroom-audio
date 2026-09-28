import 'package:flutter/material.dart';

/// Centralized design tokens + theme builders for the OpenALS app.
///
/// The visual language is a clean **green & white** system:
///  * White (and near-white) surfaces carry the primary content.
///  * Green carries the chrome: the top app bar, the bottom navigation,
///    primary buttons and call-to-action elements (with white icons/arrows
///    as a high-contrast accent).
class AppTheme {
  AppTheme._();

  /// Dark green. Used as the default accent / seed color.
  static const Color alsGreen = Color(0xFF154734);
  static const Color alsGold = Color(0xFFC9A227);

  /// Accent presets the user can choose from in Settings. The first entry is
  /// the default. Each one re-seeds the entire color scheme, while the overall
  /// green/white *structure* of the UI is preserved.
  static const List<AccentOption> accentOptions = <AccentOption>[
    AccentOption('OpenALS Green', alsGreen),
    AccentOption('Forest', Color(0xFF2E7D32)),
    AccentOption('Emerald', Color(0xFF00A36C)),
    AccentOption('Teal', Color(0xFF00897B)),
    AccentOption('Ocean', Color(0xFF1565C0)),
    AccentOption('Indigo', Color(0xFF3F51B5)),
    AccentOption('Plum', Color(0xFF7B1FA2)),
    AccentOption('Sunset', Color(0xFFE65100)),
    AccentOption('Crimson', Color(0xFFC62828)),
  ];

  static ThemeData light(Color seed, {bool highContrast = false}) =>
      _build(seed, Brightness.light, highContrast);
  static ThemeData dark(Color seed, {bool highContrast = false}) =>
      _build(seed, Brightness.dark, highContrast);

  /// True high-contrast palette, modeled on the OS "High Contrast #1" theme:
  /// pure black background with bright yellow text, borders and accents.
  static const Color _hcBackground = Color(0xFF000000);
  static const Color _hcForeground = Color(0xFFFFFF00);

  static ThemeData _build(Color seed, Brightness brightness, bool highContrast) {
    // High contrast always renders as a dark (black) canvas regardless of the
    // chosen light/dark mode, matching how OS-level high contrast behaves.
    final bool isDark = highContrast || brightness == Brightness.dark;
    final Brightness effectiveBrightness =
        isDark ? Brightness.dark : Brightness.light;

    ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: effectiveBrightness,
    );

    // High-contrast accessibility mode: a black background with vivid yellow
    // text, borders and interactive accents so everything is maximally legible.
    if (highContrast) {
      scheme = scheme.copyWith(
        brightness: Brightness.dark,
        primary: _hcForeground,
        onPrimary: Colors.black,
        secondary: _hcForeground,
        onSecondary: Colors.black,
        tertiary: _hcForeground,
        onTertiary: Colors.black,
        surface: _hcBackground,
        onSurface: _hcForeground,
        surfaceContainerHighest: _hcBackground,
        surfaceContainerHigh: _hcBackground,
        surfaceContainer: _hcBackground,
        onSurfaceVariant: _hcForeground,
        outline: _hcForeground,
        outlineVariant: _hcForeground,
        inverseSurface: _hcForeground,
        onInverseSurface: _hcBackground,
        error: _hcForeground,
        onError: Colors.black,
        errorContainer: _hcForeground,
        onErrorContainer: Colors.black,
      );
    }

    final Color scaffold = highContrast
        ? _hcBackground
        : (isDark ? const Color(0xFF0E1512) : const Color(0xFFF4F7F5));
    final Color card = highContrast
        ? _hcBackground
        : (isDark ? const Color(0xFF18211D) : Colors.white);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: effectiveBrightness,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
    );

    // In high-contrast mode, force all text to bright yellow and make it
    // heavier so glyphs are unmistakably legible against pure black.
    final TextTheme textTheme = highContrast
        ? _bolden(
            base.textTheme.apply(
              bodyColor: _hcForeground,
              displayColor: _hcForeground,
            ),
          )
        : base.textTheme;

    final Color segmentBorder =
        highContrast ? scheme.outline : scheme.outline.withValues(alpha: 0.5);

    return base.copyWith(
      textTheme: textTheme,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: segmentBorder, width: highContrast ? 2 : 1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return highContrast
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.14);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return highContrast ? scheme.onPrimary : scheme.primary;
            }
            return scheme.onSurface;
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: highContrast
              ? BorderSide(color: scheme.outline, width: 2)
              : BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.primary,
        indicatorColor: scheme.onPrimary.withValues(alpha: 0.18),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: scheme.onPrimary.withValues(alpha: selected ? 1 : 0.75),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: scheme.onPrimary.withValues(alpha: selected ? 1 : 0.75),
            size: 26,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 8,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }

  /// Push every text style to a heavier weight (used by high-contrast mode so
  /// glyphs read clearly against the pure black/white backgrounds).
  static TextTheme _bolden(TextTheme t) {
    TextStyle? bump(TextStyle? s) {
      if (s == null) return null;
      final FontWeight current = s.fontWeight ?? FontWeight.w400;
      final FontWeight heavier =
          current.value < FontWeight.w600.value ? FontWeight.w600 : current;
      return s.copyWith(fontWeight: heavier);
    }

    return t.copyWith(
      displayLarge: bump(t.displayLarge),
      displayMedium: bump(t.displayMedium),
      displaySmall: bump(t.displaySmall),
      headlineLarge: bump(t.headlineLarge),
      headlineMedium: bump(t.headlineMedium),
      headlineSmall: bump(t.headlineSmall),
      titleLarge: bump(t.titleLarge),
      titleMedium: bump(t.titleMedium),
      titleSmall: bump(t.titleSmall),
      bodyLarge: bump(t.bodyLarge),
      bodyMedium: bump(t.bodyMedium),
      bodySmall: bump(t.bodySmall),
      labelLarge: bump(t.labelLarge),
      labelMedium: bump(t.labelMedium),
      labelSmall: bump(t.labelSmall),
    );
  }
}

/// A named accent color used by the color-theme picker in Settings.
class AccentOption {
  const AccentOption(this.name, this.color);
  final String name;
  final Color color;
}
