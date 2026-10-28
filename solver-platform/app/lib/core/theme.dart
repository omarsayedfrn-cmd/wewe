import 'package:flutter/material.dart';

/// Solver Platform design tokens + light/dark themes.
///
/// Theme follows the phone (ThemeMode.system). Both palettes share one
/// discipline:
/// - burgundy is for actions and selection only.
/// - gold (brass) is for coins/wallet data only.
/// - success / error are for status feedback only.
/// - No gradients, no glows — hierarchy comes from size, weight and spacing.
@immutable
class SolverTokens extends ThemeExtension<SolverTokens> {
  const SolverTokens({
    required this.burgundy,
    required this.burgundyLight,
    required this.burgundyDark,
    required this.gold,
    required this.goldLight,
    required this.goldDark,
    required this.goldTint,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.line,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.success,
    required this.error,
    required this.warning,
  });

  final Color burgundy;
  final Color burgundyLight;
  final Color burgundyDark;
  final Color gold;
  final Color goldLight;
  final Color goldDark;
  final Color goldTint;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color line;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color success;
  final Color error;
  final Color warning;

  static const SolverTokens light = SolverTokens(
    burgundy: Color(0xFF7C1F2C),
    burgundyLight: Color(0xFFA34A56),
    burgundyDark: Color(0xFF5E1621),
    gold: Color(0xFFA6791E),
    goldLight: Color(0xFFB8924B),
    goldDark: Color(0xFF8A6414),
    goldTint: Color(0xFFF7EEDD),
    background: Color(0xFFF2F1EF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFECEBE8),
    line: Color(0xFFE3E2DE),
    onSurface: Color(0xFF211D1B),
    onSurfaceVariant: Color(0xFF6E6963),
    success: Color(0xFF1B6E4A),
    error: Color(0xFFB3261E),
    warning: Color(0xFF9A6B00),
  );

  // Restored dark palette (the original brand look).
  static const SolverTokens dark = SolverTokens(
    burgundy: Color(0xFF800020),
    burgundyLight: Color(0xFFA0334A),
    burgundyDark: Color(0xFF5C0017),
    gold: Color(0xFFD4AF37),
    goldLight: Color(0xFFE8CC6E),
    goldDark: Color(0xFFB8941F),
    goldTint: Color(0xFF2A2413),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF2A2A2A),
    line: Color(0xFF2E2E2E),
    onSurface: Color(0xFFE0E0E0),
    onSurfaceVariant: Color(0xFF9E9E9E),
    success: Color(0xFF4CAF50),
    error: Color(0xFFCF6679),
    warning: Color(0xFFFFA726),
  );

  @override
  SolverTokens copyWith({
    Color? burgundy,
    Color? burgundyLight,
    Color? burgundyDark,
    Color? gold,
    Color? goldLight,
    Color? goldDark,
    Color? goldTint,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? line,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? success,
    Color? error,
    Color? warning,
  }) {
    return SolverTokens(
      burgundy: burgundy ?? this.burgundy,
      burgundyLight: burgundyLight ?? this.burgundyLight,
      burgundyDark: burgundyDark ?? this.burgundyDark,
      gold: gold ?? this.gold,
      goldLight: goldLight ?? this.goldLight,
      goldDark: goldDark ?? this.goldDark,
      goldTint: goldTint ?? this.goldTint,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      line: line ?? this.line,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
    );
  }

  @override
  SolverTokens lerp(SolverTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SolverTokens(
      burgundy: mix(burgundy, other.burgundy),
      burgundyLight: mix(burgundyLight, other.burgundyLight),
      burgundyDark: mix(burgundyDark, other.burgundyDark),
      gold: mix(gold, other.gold),
      goldLight: mix(goldLight, other.goldLight),
      goldDark: mix(goldDark, other.goldDark),
      goldTint: mix(goldTint, other.goldTint),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      line: mix(line, other.line),
      onSurface: mix(onSurface, other.onSurface),
      onSurfaceVariant: mix(onSurfaceVariant, other.onSurfaceVariant),
      success: mix(success, other.success),
      error: mix(error, other.error),
      warning: mix(warning, other.warning),
    );
  }
}

extension SolverTokensContext on BuildContext {
  /// Design tokens for the current theme brightness.
  SolverTokens get t => Theme.of(this).extension<SolverTokens>()!;
}

/// Profile geometry for cards/controls (brightness-independent).
class SolverTheme {
  SolverTheme._();

  static const double radiusCard = 14;
  static const double radiusControl = 10;

  static ThemeData get lightTheme => _theme(SolverTokens.light, false);
  static ThemeData get darkTheme => _theme(SolverTokens.dark, true);

  static ThemeData _theme(SolverTokens c, bool isDark) {
    final base =
        isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final scheme = isDark
        ? ColorScheme.dark(
            primary: c.burgundy,
            onPrimary: Colors.white,
            secondary: c.gold,
            onSecondary: Colors.black,
            surface: c.surface,
            onSurface: c.onSurface,
            surfaceContainerHighest: c.surfaceVariant,
            onSurfaceVariant: c.onSurfaceVariant,
            error: c.error,
            onError: Colors.black,
          )
        : ColorScheme.light(
            primary: c.burgundy,
            onPrimary: Colors.white,
            primaryContainer: c.burgundy,
            onPrimaryContainer: Colors.white,
            secondary: c.gold,
            onSecondary: Colors.white,
            surface: c.surface,
            onSurface: c.onSurface,
            surfaceContainerHighest: c.surfaceVariant,
            onSurfaceVariant: c.onSurfaceVariant,
            error: c.error,
            onError: Colors.white,
            outline: c.line,
          );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
        bodyColor: c.onSurface,
        displayColor: c.onSurface,
      ),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: c.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.burgundy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.surfaceVariant,
          disabledForegroundColor: c.onSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl + 2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? c.gold : c.burgundy,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.onSurface,
          side: BorderSide(color: c.line),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl + 2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c.burgundy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: c.onSurfaceVariant),
        labelStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: c.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceVariant : c.onSurface,
        actionTextColor: isDark ? c.goldLight : c.goldLight,
        contentTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? c.onSurface : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: isDark ? c.gold : c.burgundy,
        unselectedItemColor: c.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? c.gold : c.burgundy,
        linearTrackColor: c.surfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? isDark
                  ? c.gold
                  : Colors.white
              : c.surfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? isDark
                  ? c.gold.withValues(alpha: 0.5)
                  : c.burgundy
              : c.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        labelStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.onSurface,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      iconTheme: IconThemeData(color: c.onSurfaceVariant),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
    );
  }
}
