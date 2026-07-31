import 'package:flutter/material.dart';

/// Typeface family names, matching the `family:` keys declared in
/// `pubspec.yaml`'s `flutter.fonts` section.
abstract final class TCFontFamily {
  /// §2.1's UI/body typeface.
  static const inter = 'Inter';

  /// §2.1's display/headline typeface.
  static const fraunces = 'Fraunces';
}

/// Type-scale text styles transcribed from `docs/DESIGN_SYSTEM.md` §2.2.
/// Each style is deliberately built without a color, since the same style
/// (e.g. `displayLg`) is reused on both light and dark
/// [ColorScheme.onSurface] — color is applied by `app_theme.dart` when it
/// assembles the [TextTheme], not baked in here. See `color_tokens.dart`'s
/// file header for the hand-transcribed-vs-generated disclosure that
/// applies equally to this file.
///
/// Weight disclosure: §2.2 specifies Fraunces at weight 500 (Medium) for
/// both display styles. No Medium static cut was available to bundle (see
/// pubspec.yaml's font-declaration comment) — [displayLg]/[displayMd] use
/// [FontWeight.w400] (Regular, the closer of the two available neighbors)
/// instead, a disclosed, reasoned substitution, not a silent one.
abstract final class TCTextStyles {
  /// Onboarding headlines, empty-state headlines.
  static const displayLg = TextStyle(
    fontFamily: TCFontFamily.fraunces,
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w400,
  );

  /// Table name on Table detail screen.
  static const displayMd = TextStyle(
    fontFamily: TCFontFamily.fraunces,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w400,
  );

  /// Screen titles ("Your Crews," "Discover").
  static const headingLg = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );

  /// Section headers, card titles.
  static const headingMd = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// Primary body copy, form input text.
  static const bodyLg = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Secondary body copy, list rows.
  static const bodyMd = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Timestamps, metadata, RSVP chip labels.
  static const caption = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// All button labels.
  static const button = TextStyle(
    fontFamily: TCFontFamily.inter,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
  );
}

/// Builds a Material 3 [TextTheme] from [TCTextStyles], colored for the
/// given `onSurface`/`onSurfaceVariant` pair so the same token set produces
/// correctly-contrasted text in both light and dark mode.
///
/// Mapping to Material's [TextTheme] slots is a judgment call, disclosed
/// here rather than left implicit: `docs/DESIGN_SYSTEM.md` names 8 styles,
/// Material 3's [TextTheme] has 15 slots. Every named token maps to its one
/// obvious slot (e.g. `headingLg` -> `titleLarge`, the slot Material's own
/// widgets like [AppBar] read from by default); the unnamed remainder is
/// filled by reusing the nearest sized named token rather than inventing
/// new, undocumented sizes.
TextTheme buildTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
}) {
  TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  return TextTheme(
    displayLarge: withColor(TCTextStyles.displayLg, onSurface),
    displayMedium: withColor(TCTextStyles.displayMd, onSurface),
    displaySmall: withColor(TCTextStyles.displayMd, onSurface),
    headlineLarge: withColor(TCTextStyles.displayMd, onSurface),
    headlineMedium: withColor(TCTextStyles.headingLg, onSurface),
    headlineSmall: withColor(TCTextStyles.headingMd, onSurface),
    titleLarge: withColor(TCTextStyles.headingLg, onSurface),
    titleMedium: withColor(TCTextStyles.headingMd, onSurface),
    titleSmall: withColor(TCTextStyles.bodyLg, onSurface),
    bodyLarge: withColor(TCTextStyles.bodyLg, onSurface),
    bodyMedium: withColor(TCTextStyles.bodyMd, onSurface),
    bodySmall: withColor(TCTextStyles.caption, onSurfaceVariant),
    labelLarge: withColor(TCTextStyles.button, onSurface),
    labelMedium: withColor(TCTextStyles.caption, onSurfaceVariant),
    labelSmall: withColor(TCTextStyles.caption, onSurfaceVariant),
  );
}
