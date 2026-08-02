import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/features/tables/application/home_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';
import 'package:tablecrew/widgets/status_chip.dart';

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Screen 9 (Home / My Tables), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// **Scope notes for this first F6 chunk, disclosed not silent:**
/// - The spec's "stacked-avatar attendee preview" per Table Card is not
///   built: `firestore.rules` denies a non-host reading other attendees'
///   RSVP documents (by design — see the rsvps rules), and the Table
///   document carries no denormalized attendee-avatar snapshots for a card
///   to render from. Building the preview needs a schema addition (an
///   attendee-preview field maintained by the RSVP callables/a trigger,
///   `docs/DATABASE.md` §4's denormalization pattern) — flagged in
///   `TASKS.md` as a follow-up, not quietly worked around. The card shows
///   "N of M going" from `capacity.confirmedCount` instead.
/// - The "Rate this Table" nudge on Happened cards deep-links to
///   Post-Table Rating, which is F8 scope — Happened cards render in their
///   correct sort band now, and the nudge affordance lands with F8.
/// - Waitlist position inline on a Waitlisted card needs the Waitlist
///   surface (F8) — the card renders its Waitlisted chip without a
///   position number until then.
/// - Tab-bar navigation chrome (the persistent Home/Discover/... shell)
///   is deliberately not built here — see `app_router.dart`'s "Navigation
///   shell structure is NOT decided here" note; this screen fills whatever
///   route hosts it.
///
/// Added Milestone F6.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the Home screen.
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showingCrews = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    final connectivity = ref.read(connectivityRepositoryProvider);
    unawaited(_checkInitialConnectivity(connectivity));
    _connectivitySubscription = connectivity.offlineChanges.listen((
      isOffline,
    ) {
      if (!mounted) return;
      setState(() => _isOffline = isOffline);
    });
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  Future<void> _checkInitialConnectivity(
    ConnectivityRepository connectivity,
  ) async {
    final isOffline = await connectivity.isOffline();
    if (!mounted) return;
    setState(() => _isOffline = isOffline);
  }

  Future<void> _refresh() async {
    if (_isOffline) {
      // Offline Behavior: "Pull-to-refresh while offline shows an inline
      // 'Can't refresh while offline' toast rather than an infinite
      // skeleton-pulse."
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't refresh while offline")),
      );
      return;
    }
    ref.invalidate(homeControllerProvider);
    await ref.read(homeControllerProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final homeData = ref.watch(homeControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed('create-table'),
        label: const Text('Create a Table'),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOffline)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TCSpacing.md,
                  vertical: TCSpacing.xs,
                ),
                color: colors.surfaceContainerHighest,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Offline — showing saved Tables',
                    style: TCTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(TCSpacing.md),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('My Tables')),
                  ButtonSegment(value: true, label: Text('My Crews')),
                ],
                selected: {_showingCrews},
                onSelectionChanged: (selection) {
                  setState(() => _showingCrews = selection.first);
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: homeData.when(
                  loading: _buildSkeletons,
                  error: (error, _) => _buildError(colors),
                  data: (data) => _showingCrews
                      ? _buildCrewsList(data.crews, colors)
                      : _buildTablesList(data.tables, colors),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading States: "3-4 skeleton-pulse Table/Crew Card placeholders ...
  /// matching the exact card layout ... Never a spinner."
  Widget _buildSkeletons() {
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.md),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: TCSpacing.md),
            child: SkeletonPulse(width: double.infinity, height: 88),
          ),
      ],
    );
  }

  Widget _buildError(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.xl),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            "Couldn't load your Tables — pull to retry.",
            textAlign: TextAlign.center,
            style: TCTextStyles.bodyMd.copyWith(color: colors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildTablesList(List<HomeTableCard> cards, ColorScheme colors) {
    if (cards.isEmpty) {
      return _buildEmptyState(
        colors,
        headline: 'Your first Table starts here',
        body: 'Create a Table or find one on Discover',
        showCreateButton: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.md),
      children: [for (final card in cards) _TableCard(card: card)],
    );
  }

  Widget _buildCrewsList(List<CrewSummary> crews, ColorScheme colors) {
    if (crews.isEmpty) {
      return _buildEmptyState(
        colors,
        headline: 'No Crews yet',
        body: 'Tables you attend together can become a Crew',
        showCreateButton: false,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.md),
      children: [for (final crew in crews) _CrewCard(crew: crew)],
    );
  }

  Widget _buildEmptyState(
    ColorScheme colors, {
    required String headline,
    required String body,
    required bool showCreateButton,
  }) {
    // ListView (not Column) so RefreshIndicator's pull gesture still works
    // on an empty tab.
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.xl),
      children: [
        const SizedBox(height: TCSpacing.xxl),
        // Empty States: "an illustration of an empty table setting" — a
        // real illustration asset doesn't exist yet; a decorative icon
        // stands in (marked decorative, same treatment as Screen 7's
        // illustration).
        Center(
          child: ExcludeSemantics(
            child: Icon(
              Icons.table_restaurant_outlined,
              size: 64,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: TCSpacing.lg),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TCTextStyles.displayMd.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: TCSpacing.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TCTextStyles.bodyMd.copyWith(color: colors.onSurfaceVariant),
        ),
        if (showCreateButton) ...[
          const SizedBox(height: TCSpacing.lg),
          Center(
            child: ElevatedButton(
              onPressed: () => context.goNamed('create-table'),
              child: const Text('Create a Table'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.card});

  final HomeTableCard card;

  String _formatStart(DateTime start) {
    final month = _monthAbbreviations[start.month - 1];
    final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final minute = start.minute.toString().padLeft(2, '0');
    final period = start.hour < 12 ? 'AM' : 'PM';
    return '$month ${start.day}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final table = card.table;
    final when = _formatStart(table.startTime);
    final where = table.venueName ?? 'Venue TBD';
    final going = '${table.confirmedCount} of ${table.capacityMax} going';

    // Accessibility Notes: "one combined accessibility label per card ...
    // rather than forcing screen-reader users to piece together each
    // visual element separately."
    return Semantics(
      button: true,
      label: '${table.title}, $where, $when, '
          '${card.statusLabel}, $going',
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: TCSpacing.md),
          child: InkWell(
            onTap: () => context.goNamed(
              'table-detail',
              pathParameters: {'tableId': table.id},
            ),
            child: Padding(
              padding: const EdgeInsets.all(TCSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          table.title,
                          style: TCTextStyles.headingMd.copyWith(
                            color: colors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusChip(
                        status: card.displayStatus,
                        label: card.statusLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: TCSpacing.xs),
                  Text(
                    '$where · $when',
                    style: TCTextStyles.bodyMd.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TCSpacing.xs),
                  Text(
                    going,
                    style: TCTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrewCard extends StatelessWidget {
  const _CrewCard({required this.crew});

  final CrewSummary crew;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final members =
        '${crew.memberCount} member${crew.memberCount == 1 ? '' : 's'}';

    return Semantics(
      button: true,
      label: '${crew.name}, $members',
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: TCSpacing.md),
          child: InkWell(
            onTap: () => context.goNamed(
              'crew-detail',
              pathParameters: {'crewId': crew.id},
            ),
            child: Padding(
              padding: const EdgeInsets.all(TCSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crew.name,
                          style: TCTextStyles.headingMd.copyWith(
                            color: colors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: TCSpacing.xs),
                        Text(
                          members,
                          style: TCTextStyles.caption.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.goNamed('create-table'),
                    child: const Text('Schedule a Table'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
