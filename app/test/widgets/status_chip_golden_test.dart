import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/core/theme/app_theme.dart';
import 'package:tablecrew/core/theme/rsvp_status_colors.dart';
import 'package:tablecrew/widgets/status_chip.dart';

/// Golden coverage for [StatusChip] (Recommendation R2) — the first
/// component `docs/DESIGN_SYSTEM.md` names explicitly as a golden-test
/// target ("core component library (buttons, cards, chips, RSVP status
/// chips)", `docs/IMPLEMENTATION_PLAN.md`'s R2 text). Buttons/cards get
/// their own golden tests once a themed instance of each exists outside
/// `app_theme.dart`'s component-theme defaults (none does yet, Milestone
/// F3 — see `core/README.md`).
///
/// Labels used below are placeholder display text for golden-image
/// purposes only, not `docs/COPY_GUIDELINES.md`-approved copy — see
/// [StatusChip]'s own doc comment on why the widget itself doesn't
/// hard-code label strings.
///
/// [_scenarios] is a plain data list, not a list of [GoldenTestScenario]
/// widgets: [GoldenTestScenario]'s public API only exposes `name` and a
/// `builder`, not the original `child` its regular constructor takes (it's
/// converted internally to a `WidgetBuilder` and not stored as a
/// retrievable field — confirmed against Alchemist 0.14.0's own source,
/// not assumed). Building [GoldenTestScenario]s fresh for both the light-
/// and dark-theme tests below from this shared data avoids depending on
/// a field that doesn't exist.
void main() {
  group('StatusChip', () {
    goldenTest(
      'renders every RsvpDisplayStatus, light theme',
      fileName: 'status_chip_light',
      builder: () => GoldenTestGroup(
        children: [
          for (final scenario in _scenarios)
            GoldenTestScenario(
              name: scenario.name,
              child: StatusChip(status: scenario.status, label: scenario.label),
            ),
        ],
      ),
    );

    goldenTest(
      'renders every RsvpDisplayStatus, dark theme',
      fileName: 'status_chip_dark',
      builder: () => GoldenTestGroup(
        children: [
          for (final scenario in _scenarios)
            GoldenTestScenario(
              name: scenario.name,
              // A Theme widget is a genuine ancestor in the render tree, so
              // Theme.of(context) inside StatusChip resolves to the dark
              // scheme exactly as it would in the real app - overriding
              // flutter_test_config.dart's ambient light-theme default for
              // just this scenario's subtree, no Alchemist-specific
              // theming mechanism required.
              child: Theme(
                data: TCAppTheme.dark(),
                child: StatusChip(
                  status: scenario.status,
                  label: scenario.label,
                ),
              ),
            ),
        ],
      ),
    );
  });
}

/// One row per [RsvpDisplayStatus] — the display-level enum
/// `core/theme/rsvp_status_colors.dart` defines, per
/// `docs/DESIGN_SYSTEM.md` §1.3.
const List<({String name, RsvpDisplayStatus status, String label})> _scenarios =
    [
  (name: 'going', status: RsvpDisplayStatus.going, label: 'Going'),
  (name: 'requested', status: RsvpDisplayStatus.requested, label: 'Requested'),
  (
    name: 'waitlisted',
    status: RsvpDisplayStatus.waitlisted,
    label: 'Waitlisted',
  ),
  (name: 'notGoing', status: RsvpDisplayStatus.notGoing, label: 'Not Going'),
  (name: 'cancelled', status: RsvpDisplayStatus.cancelled, label: 'Cancelled'),
];
