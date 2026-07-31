import 'package:flutter/material.dart';

/// Raw color tokens transcribed directly from `docs/DESIGN_SYSTEM.md` §1
/// ("Color System"). These are the named brand values design owns — never
/// hand-typed as hex literals elsewhere in the app; every widget reaches
/// for a token here (or a [ColorScheme] slot built from these tokens in
/// `app_theme.dart`), per §10's "engineers never hand-type a hex value"
/// rule.
///
/// Milestone F3 scope note: `docs/DESIGN_SYSTEM.md` §10 describes an
/// eventual Figma -> `design-tokens.json` -> generated
/// `lib/theme/generated_tokens.dart` pipeline. That pipeline (the Figma
/// library, the token-export plugin, the build script) does not exist yet
/// — nobody has built it, and this milestone doesn't either. Per
/// `docs/IMPLEMENTATION_PLAN.md`'s Milestone F3 row, this file is
/// deliberately **hand-transcribed** from the written doc instead, as an
/// explicit, disclosed interim step. When the real token pipeline lands,
/// this file is what gets replaced by its generated output — the token
/// *names* below are chosen to match what §10 says the generated file will
/// expose (e.g. `TCColors.primary600`), so that swap is a mechanical one.
abstract final class TCColors {
  // --- §1.2 Primary Palette ---------------------------------------------

  /// Terracotta — primary buttons, active states, key CTAs.
  static const primary600 = Color(0xFFC1653A);

  /// Terracotta Light — hover/pressed states, secondary emphasis.
  static const primary500 = Color(0xFFD97F52);

  /// Terracotta Tint — selected chips, subtle highlight backgrounds.
  static const primary100 = Color(0xFFF3DDD0);

  /// Amber — secondary accent (RSVP "Going" confirmations, Crew milestones).
  static const accent600 = Color(0xFFE0A339);

  /// Ink Charcoal — primary text, headlines, icons on light backgrounds.
  static const ink900 = Color(0xFF2B241F);

  /// Ink Charcoal Muted — secondary text, captions, metadata.
  static const ink700 = Color(0xFF524A43);

  /// Linen Cream — primary app background.
  static const neutral0 = Color(0xFFFBF6EF);

  /// Card Cream — card surfaces, sheet backgrounds.
  static const neutral50 = Color(0xFFF5EEE3);

  /// Warm Grey — dividers, borders, disabled states.
  static const neutral200 = Color(0xFFDCD2C4);

  /// Sage — "Going" / confirmed states.
  static const success600 = Color(0xFF5E7A5A);

  /// Gold Ochre — "Waitlisted" / pending states.
  static const warning600 = Color(0xFFB98A1F);

  /// Brick — errors, "Cancelled" states, destructive actions. Reserved
  /// exclusively for these per §1.3 — never used for declines or minor
  /// form validation.
  static const danger600 = Color(0xFFA94A3D);

  // --- §1.4 Dark Mode ------------------------------------------------------
  // Warmth-preserving shifts of the light-mode tokens above, never a hue
  // rotation into blue-black or grayscale (§9's one-line principle).

  /// Dark background — warm near-black, not pure `#000000` or cool slate.
  static const darkBackground = Color(0xFF1E1A16);

  /// Dark card surface.
  static const darkSurface = Color(0xFF2A241F);

  /// Dark-mode primary text.
  static const darkOnSurface = Color(0xFFF3ECE0);

  /// Dark-mode terracotta primary — lightened ~12% from [primary600] for
  /// sufficient contrast against [darkBackground] (verified ~6.6:1 per
  /// §1.4, exceeding the 4.5:1 AA minimum).
  static const darkPrimary = Color(0xFFE08A5C);

  /// Dark-mode divider.
  static const darkDivider = Color(0xFF3A332C);
}
