import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';

/// The five RSVP/Table-status display states `docs/DESIGN_SYSTEM.md` §1.3
/// defines a dedicated color mapping for — "one of the most-seen UI
/// elements in the app (every Table card, every Crew roster)."
///
/// This is a **display-level** enum, not a 1:1 mirror of either Firestore
/// enum in `docs/DATABASE.md`: a Table document's own `status` field is
/// `"proposed" | "filling" | "confirmed" | "happened" | "rated" |
/// "cancelled"` (§3.1), and an RSVP subcollection document's `status` is
/// the richer `"invited" | "requested" | "confirmed" | "declined" |
/// "waitlisted" | "attended" | "no_show"` (§3.2) — neither matches the
/// design system's 5-value chip vocabulary directly (e.g. both a Table's
/// `"confirmed"` and an RSVP's `"attended"` should likely render as the
/// same "Going" chip, but which Firestore states map to which chip is a
/// business-logic/DTO decision that depends on the RSVP repository layer,
/// which does not exist yet — see `app/lib/data/README.md`). Deliberately
/// not resolved here: this file owns the *color a display state gets*, not
/// *which Firestore states produce that display state*. That mapping
/// belongs with whichever feature milestone (F4+) first builds a real RSVP
/// chip widget against real repository data.
enum RsvpDisplayStatus {
  /// Sage. "Green family reads 'confirmed' universally... stays inside the
  /// warm, muted palette family" (§1.3).
  going,

  /// Terracotta Light. "Uses the brand's own primary hue so a pending
  /// request feels like 'in progress,' not 'wrong'" (§1.3).
  requested,

  /// Gold Ochre. "The most globally-legible 'please wait' signal... distinct
  /// enough from Requested to avoid confusion" (§1.3).
  waitlisted,

  /// Warm Grey on Ink text. "Neutral, non-punitive — declining a Table
  /// should never look like an error or a red flag" (§1.3).
  notGoing,

  /// Brick. Reserved exclusively for Table cancellation — never reused for
  /// declines or minor form validation (§1.3's closing rule: "Red is
  /// intentionally used nowhere else in the system").
  cancelled,
}

/// The background/fill color for a given [RsvpDisplayStatus], per
/// `docs/DESIGN_SYSTEM.md` §1.3's mapping table.
Color rsvpStatusColor(RsvpDisplayStatus status) {
  switch (status) {
    case RsvpDisplayStatus.going:
      return TCColors.success600;
    case RsvpDisplayStatus.requested:
      return TCColors.primary500;
    case RsvpDisplayStatus.waitlisted:
      return TCColors.warning600;
    case RsvpDisplayStatus.notGoing:
      return TCColors.neutral200;
    case RsvpDisplayStatus.cancelled:
      return TCColors.danger600;
  }
}

/// Whether a chip for this status renders filled (solid background,
/// [TCColors.neutral0] cream text) or outlined (transparent fill, colored
/// border + text), per `docs/DESIGN_SYSTEM.md` §4.3: Waitlisted is
/// deliberately outlined "to visually de-emphasize a pending/uncertain
/// state relative to a confirmed one," while every other status is filled.
/// "Not Going" is the one filled exception that pairs its fill with *ink*
/// text rather than cream, since Warm Grey is too light for cream text to
/// contrast against — see `StatusChip` in `widgets/status_chip.dart`, the
/// only place this function's result should be consumed.
bool rsvpStatusIsOutlined(RsvpDisplayStatus status) =>
    status == RsvpDisplayStatus.waitlisted;
