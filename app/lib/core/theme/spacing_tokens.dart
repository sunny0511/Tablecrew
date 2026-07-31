/// Spacing tokens transcribed from `docs/DESIGN_SYSTEM.md` §3 ("Spacing and
/// Grid") — a 4pt base unit scale, per iOS HIG and Android Material
/// convention. See `color_tokens.dart`'s file header for why this is
/// hand-transcribed rather than generated from a Figma token export.
abstract final class TCSpacing {
  /// Icon-to-label gaps, chip internal padding.
  static const xs = 4.0;

  /// Compact stacking (avatar-to-name).
  static const sm = 8.0;

  /// Standard component padding, gap between form fields.
  static const md = 16.0;

  /// Card padding, section gaps.
  static const lg = 24.0;

  /// Screen-edge margins, gap between major sections. Also the minimum
  /// left/right screen margin per §3 ("wider than the more common 16px
  /// default... a well-set table with room between place settings").
  static const xl = 32.0;

  /// Empty-state vertical rhythm, onboarding breathing room.
  static const xxl = 48.0;

  /// Card corner radius (§3: "16px corner radius on cards").
  static const radiusCard = 16.0;

  /// Corner radius for buttons and input fields (§3: "12px on buttons and
  /// input fields").
  static const radiusControl = 12.0;

  /// Minimum interactive touch target size (§6 Accessibility: "minimum
  /// 44x44pt (iOS) / 48x48dp (Android)"). Using 48 — the larger of the two
  /// platform minimums — as one constant so a single value satisfies both,
  /// rather than branching by platform. Matches Flutter Material's own
  /// `kMinInteractiveDimension`.
  static const minTouchTarget = 48.0;
}
