/// A single entry in the interest-tag taxonomy: the wire value stored on
/// `users/{uid}.interestTags` / `tables/{tableId}.interestTag`
/// (`docs/DATABASE.md` §3.1/§3.2) paired with its display label.
class InterestTagOption {
  /// Creates a taxonomy entry.
  const InterestTagOption({required this.tag, required this.label});

  /// The wire value (e.g. `'founder_dinners'`).
  final String tag;

  /// The user-facing label (e.g. `'Founder Dinners'`).
  final String label;
}

/// The starter interest-tag taxonomy, shown as Screen 6 (Interest
/// Selection)'s chip grid and, later, Settings' "Edit interests" (per
/// `docs/SCREEN_SPECIFICATIONS.md` Screen 6's Entry Points).
///
/// **Mirrors, not re-derives, `functions/src/tables/validation.ts`'s**
/// `KNOWN_INTEREST_TAGS` — the *only* closed taxonomy actually enforced
/// anywhere in this codebase today (by `createTable`'s `interestTag`
/// field validator). There is no shared Dart/TypeScript source for this
/// list to generate from, so this file is a disclosed, hand-kept mirror;
/// if the two ever diverge, `functions/src/tables/validation.ts`'s
/// comment block is the one to treat as authoritative, per that file's
/// own "Foundation/Phase-0-scoped starter list" framing.
///
/// **Disclosed gap #1 (pre-existing, not introduced by this file):**
/// `functions/src/users/validation.ts`'s `isValidInterestTags` — the
/// validator `completeAccountSetup` actually runs — does **not**
/// cross-check submitted tags against this taxonomy at all; it only
/// checks array length (>= 3) and that each entry is a non-empty string.
/// A client could submit any string and the server would accept it. This
/// screen's UI still only ever offers taxonomy chips (a client can't
/// construct an arbitrary tag through normal use), so the gap is latent
/// rather than exploitable through this screen — but it means the
/// server-side invariant `createTable`'s tag enforces is *not* actually
/// guaranteed for `users/{uid}.interestTags`. Flagged here rather than
/// silently built around, since closing it means touching
/// `functions/src/users/validation.ts` (Cloud Functions code, outside
/// this milestone's Flutter-client scope) — tracked as a follow-up, not
/// fixed in this pass.
///
/// **Disclosed gap #2:** `docs/SCREEN_SPECIFICATIONS.md` Screen 6's own
/// UI Components example list additionally names "Mentorship," which
/// isn't in `KNOWN_INTEREST_TAGS` — another sign this is a starter list,
/// not a finished one. Not added here unilaterally, since adding a new
/// tag value on the Flutter side without a matching update to
/// `functions/src/tables/validation.ts` (and a decision on whether
/// `createTable` should also accept it) would itself create a fresh
/// cross-document mismatch of exactly the kind this comment is
/// disclosing about the existing six.
///
/// Added Milestone F5.
const List<InterestTagOption> kInterestTaxonomy = [
  InterestTagOption(tag: 'coffee', label: 'Coffee'),
  InterestTagOption(tag: 'lunch', label: 'Lunch'),
  InterestTagOption(tag: 'founder_dinners', label: 'Founder Dinners'),
  InterestTagOption(tag: 'dinner', label: 'Dinner'),
  InterestTagOption(tag: 'board_games', label: 'Board Games'),
  InterestTagOption(tag: 'hiking', label: 'Hiking'),
];

/// Screen 6's stated minimum: "Pick at least 3 — you can change these
/// anytime."
const int kMinInterestTags = 3;
