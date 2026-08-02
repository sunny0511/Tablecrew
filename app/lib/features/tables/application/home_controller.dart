import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/theme/rsvp_status_colors.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';

part 'home_controller.g.dart';

/// One Table Card row on Home (Screen 9) — a [TableSummary] joined with
/// how *this user* relates to it, resolved to the design system's 5-value
/// chip vocabulary. This is the display-status mapping
/// `core/theme/rsvp_status_colors.dart`'s doc comment explicitly deferred
/// to "whichever feature milestone first builds a real RSVP chip widget
/// against real repository data" — that's here.
class HomeTableCard {
  /// Creates a card row.
  const HomeTableCard({
    required this.table,
    required this.isHost,
    required this.displayStatus,
    required this.statusLabel,
  });

  /// The Table.
  final TableSummary table;

  /// Whether the signed-in user hosts this Table.
  final bool isHost;

  /// Which chip to render.
  final RsvpDisplayStatus displayStatus;

  /// The chip's label text.
  final String statusLabel;
}

/// Everything Home renders, loaded in one pass.
class HomeData {
  /// Creates the loaded state.
  const HomeData({required this.tables, required this.crews});

  /// Table Cards, already in Screen 9's display order.
  final List<HomeTableCard> tables;

  /// Crew Cards.
  final List<CrewSummary> crews;
}

/// Maps a Table + the user's relationship to it onto the design system's
/// chip vocabulary (docs/DESIGN_SYSTEM.md §1.3). Rules, in precedence
/// order:
/// - A cancelled Table renders the Brick "Cancelled" chip no matter what
///   the user's RSVP said ("plus Brick for a Cancelled Table the user was
///   on", Screen 9's UI Components).
/// - The host of any non-cancelled Table is definitionally going.
/// - Otherwise the RSVP status maps: confirmed/attended -> Going,
///   requested -> Requested, invited -> the same Terracotta-Light pending
///   chip labeled "Invited" (an invitation awaiting response is a pending
///   state, which is exactly what §1.3 says that hue communicates — the
///   5-value enum has no separate invited slot), waitlisted -> Waitlisted.
///   declined/no_show never reach Home (excluded at the query,
///   [TablesRepository.fetchMyRsvps]).
HomeTableCard buildHomeTableCard({
  required TableSummary table,
  required bool isHost,
  RsvpStatus? rsvpStatus,
}) {
  if (table.status == TableStatus.cancelled) {
    return HomeTableCard(
      table: table,
      isHost: isHost,
      displayStatus: RsvpDisplayStatus.cancelled,
      statusLabel: 'Cancelled',
    );
  }
  if (isHost) {
    return HomeTableCard(
      table: table,
      isHost: true,
      displayStatus: RsvpDisplayStatus.going,
      statusLabel: 'Going',
    );
  }
  final (status, label) = switch (rsvpStatus) {
    RsvpStatus.confirmed || RsvpStatus.attended => (
        RsvpDisplayStatus.going,
        'Going'
      ),
    RsvpStatus.requested => (RsvpDisplayStatus.requested, 'Requested'),
    RsvpStatus.invited => (RsvpDisplayStatus.requested, 'Invited'),
    RsvpStatus.waitlisted => (RsvpDisplayStatus.waitlisted, 'Waitlisted'),
    _ => (RsvpDisplayStatus.requested, 'Requested'),
  };
  return HomeTableCard(
    table: table,
    isHost: false,
    displayStatus: status,
    statusLabel: label,
  );
}

/// Screen 9's client-side sort (Validation Rules: "soonest-upcoming Table
/// first, then Happened-but-unrated Tables surfaced with a rating nudge,
/// then further-future Tables, then Cancelled Tables deprioritized to the
/// bottom"): upcoming Tables by soonest start, then `happened` (the
/// rating-nudge band — the nudge UI itself is F8's Post-Table Rating
/// scope, but the ordering slot exists now), then `rated`, then
/// `cancelled` last.
List<HomeTableCard> sortHomeTableCards(List<HomeTableCard> cards) {
  int band(HomeTableCard card) {
    return switch (card.table.status) {
      TableStatus.proposed ||
      TableStatus.filling ||
      TableStatus.confirmed ||
      TableStatus.unknown =>
        0,
      TableStatus.happened => 1,
      TableStatus.rated => 2,
      TableStatus.cancelled => 3,
    };
  }

  final sorted = [...cards]..sort((a, b) {
      final byBand = band(a).compareTo(band(b));
      if (byBand != 0) return byBand;
      return a.table.startTime.compareTo(b.table.startTime);
    });
  return sorted;
}

/// Loads Home (Screen 9)'s data: hosted Tables, RSVP'd Tables (via the
/// rsvps collection-group query, then resolving each Table document), and
/// Crews — merged, mapped to chip vocabulary, and sorted.
///
/// A plain async build with no custom methods: pull-to-refresh is
/// `ref.invalidate(homeControllerProvider)` from the widget, and Riverpod's
/// `AsyncValue` already models loading/error/data for the screen.
///
/// Added Milestone F6.
@riverpod
class HomeController extends _$HomeController {
  @override
  Future<HomeData> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      // Unreachable in the real flow (Splash routes signed-out users away
      // from Home) — a defensive empty state, not an expected path.
      return const HomeData(tables: [], crews: []);
    }

    final tablesRepository = ref.read(tablesRepositoryProvider);
    final crewsRepository = ref.read(crewsRepositoryProvider);

    final (hosted, rsvps, crews) = await (
      tablesRepository.fetchHostedTables(uid),
      tablesRepository.fetchMyRsvps(uid),
      crewsRepository.fetchMyCrews(uid),
    ).wait;

    final cards = <String, HomeTableCard>{
      for (final table in hosted)
        table.id: buildHomeTableCard(table: table, isHost: true),
    };
    for (final rsvp in rsvps) {
      // A hosted Table the user somehow also has an RSVP row on keeps its
      // host card — the host mapping wins.
      if (cards.containsKey(rsvp.tableId)) continue;
      final table = await tablesRepository.fetchTable(rsvp.tableId);
      // null = deleted/unreadable since the RSVP was written; skip the
      // stale row rather than rendering a broken card.
      if (table == null) continue;
      cards[rsvp.tableId] = buildHomeTableCard(
        table: table,
        isHost: false,
        rsvpStatus: rsvp.status,
      );
    }

    return HomeData(
      tables: sortHomeTableCards(cards.values.toList()),
      crews: crews,
    );
  }
}
