import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';

/// Builds TableCrew's Material 3 [ThemeData] for both brightness modes,
/// per `docs/DESIGN_SYSTEM.md`. See `color_tokens.dart`'s header for the
/// hand-transcribed-vs-generated scope note (Recommendation R3), and
/// §3's "Implementation note (added 2026-08)": Material 3 is the
/// *mechanism* (`useMaterial3: true`), fully re-themed with TableCrew's
/// own tokens — only M3's theming plumbing and built-in accessibility/RTL
/// support are inherited as-is.
abstract final class TCAppTheme {
  /// The light-mode [ThemeData], per `docs/DESIGN_SYSTEM.md` §1.2's
  /// primary palette.
  static ThemeData light() => _build(brightness: Brightness.light);

  /// The dark-mode [ThemeData], per `docs/DESIGN_SYSTEM.md` §1.4.
  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _buildColorScheme(brightness);
    final textTheme = buildTextTheme(
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,

      // §4.1 Buttons: 12px radius, 48px minimum height (exceeds both
      // platforms' minimum tap target — see TCSpacing.minTouchTarget).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(TCSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
          ),
          textStyle: TCTextStyles.button,
          disabledBackgroundColor:
              colorScheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor:
              colorScheme.onPrimary.withValues(alpha: 0.4),
        ),
      ),
      // §4.1 Secondary button: outlined, 1.5px Ink Charcoal border,
      // transparent fill, Ink Charcoal text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size.fromHeight(TCSpacing.minTouchTarget),
          side: BorderSide(color: colorScheme.onSurface, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
          ),
          textStyle: TCTextStyles.button,
        ),
      ),
      // §4.1 Tertiary / text button: no border or fill, Terracotta text.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(
            TCSpacing.minTouchTarget,
            TCSpacing.minTouchTarget,
          ),
          textStyle: TCTextStyles.button,
        ),
      ),

      // §4.2 Cards: Card Cream surface, 16px radius, hairline Warm Grey
      // border, no drop shadow ("a hairline border reads as 'placemat on a
      // table'").
      cardTheme: CardThemeData(
        color: isDark ? TCColors.darkSurface : TCColors.neutral50,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TCSpacing.radiusCard),
          side: BorderSide(
            color: isDark ? TCColors.darkDivider : TCColors.neutral200,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // §3 Corner radius: 12px on input fields, matching buttons.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? TCColors.darkSurface : TCColors.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
          borderSide: BorderSide(
            color: isDark ? TCColors.darkDivider : TCColors.neutral200,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? TCColors.darkDivider : TCColors.neutral200,
        thickness: 1,
        space: 1,
      ),

      // §8 Motion: "warm and unhurried" — longer-than-default transition
      // durations. Page-transition curves/durations themselves are wired
      // up with GoRouter's custom transition builders (see
      // core/routing/app_router.dart), not here; this only covers the
      // handful of built-in Material transitions (e.g. [PageTransitionsTheme])
      // that don't go through GoRouter.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: _UnhurriedPageTransitionsBuilder(),
          TargetPlatform.android: _UnhurriedPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Maps TableCrew's named tokens to the M3 [ColorScheme] slots they
  /// obviously correspond to, and lets [ColorScheme.fromSeed] derive the
  /// remaining ~19 unnamed slots via M3's standard tonal-palette generation
  /// (Recommendation R3) — rather than hand-guessing values for slots like
  /// `primaryContainer`/`surfaceContainerHigh` that no design token names.
  /// Passing `primary`/`secondary`/`tertiary`/`error` as seed overrides
  /// (not a plain `.copyWith` after the fact) so the algorithm regenerates
  /// each color's own dependent container/`on*` tones in harmony with our
  /// override, instead of leaving them derived from the base `seedColor`
  /// while only the top-level slot itself changes.
  static ColorScheme _buildColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: TCColors.primary600,
      primary: isDark ? TCColors.darkPrimary : TCColors.primary600,
      // Amber — "secondary accent" per §1.2.
      secondary: TCColors.accent600,
      // Sage — no M3 "success" slot exists; tertiary is the standard home
      // for a third brand accent, per R3's "obviously correspond" guidance
      // applied to the one token family without a direct M3 name.
      tertiary: TCColors.success600,
      error: TCColors.danger600,
      surface: isDark ? TCColors.darkBackground : TCColors.neutral0,
      onSurface: isDark ? TCColors.darkOnSurface : TCColors.ink900,
      onSurfaceVariant: isDark ? TCColors.darkOnSurface : TCColors.ink700,
      outline: isDark ? TCColors.darkDivider : TCColors.neutral200,
    );
  }
}

/// §8 Motion and Animation Principles: "all transitions use an ease-in-out
/// curve with slightly longer durations than typical mobile defaults —
/// 250-350ms for standard screen transitions (vs. the common 150-200ms)."
///
/// This builder covers the curve; it deliberately does NOT attempt to
/// override the transition's *duration* — that's a property of the
/// [PageRoute]/[Page] driving the transition, not of
/// [PageTransitionsBuilder] itself (there is no `transitionDuration`
/// member on this base class to override). The actual 250-350ms timing is
/// therefore set where GoRouter's route table (see
/// `core/routing/app_router.dart`, Milestone F3's router deliverable)
/// builds each screen as a `CustomTransitionPage`, which does expose an
/// explicit `transitionDuration` parameter — the correct, precise
/// mechanism for this, rather than fighting this theme-level API for
/// something it isn't designed to control.
class _UnhurriedPageTransitionsBuilder extends PageTransitionsBuilder {
  const _UnhurriedPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
