# widgets/

Shared, feature-agnostic UI components that consume the design system (buttons, cards, chips, RSVP status chips) — per `docs/DESIGN_SYSTEM.md` §4's component specs.

**Scaffold note (Milestone F0):** empty. Populated starting in Milestone F3 ("Client foundation"), alongside the golden-test harness (Recommendation R2 in `docs/IMPLEMENTATION_PLAN.md`) so these components get visual-regression coverage from the moment they're written, not retrofitted later.

**Milestone F3:** `status_chip.dart` is the first component here, with light- and dark-theme golden coverage in `app/test/widgets/status_chip_golden_test.dart` (Alchemist, per Recommendation R2 — see `app/test/flutter_test_config.dart` for the package-wide config and `.gitignore` for why only the Ahem-font `goldens/ci/` images are committed). Buttons and cards get their own golden tests once a themed instance of each exists outside `app_theme.dart`'s component-theme defaults — none does yet.
