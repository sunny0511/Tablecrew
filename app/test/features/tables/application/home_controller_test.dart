import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/theme/rsvp_status_colors.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/application/home_controller.dart';

import '../../../fakes/fake_crews_repository.dart';
import '../../../fakes/fake_tables_repository.dart';

/// Unit tests for [HomeController]'s merge/mapping/sort logic and the
/// [buildHomeTableCard]/[sortHomeTableCards] helpers — the display-status
/// mapping `core/theme/rsvp_status_colors.dart` deferred to this layer
/// (Milestone F6).
void main() {
  late FakeTablesRepository tablesRepository;
  late FakeCrewsRepository crewsRepository;
  late ProviderContainer container;

  setUp(() {
    tablesRepository = FakeTablesRepository();
    crewsRepository = FakeCrewsRepository();
    container = ProviderContainer(
      overrides: [
        tablesRepositoryProvider.overrideWithValue(tablesRepository),
        crewsRepositoryProvider.overrideWithValue(crewsRepository),
        currentUidProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(container.dispose);
  });

  group('buildHomeTableCard', () {
    test('a cancelled Table renders the Cancelled chip even for the host', () {
      final card = buildHomeTableCard(
        table: buildTestTableSummary(status: TableStatus.cancelled),
        isHost: true,
      );
      expect(card.displayStatus, RsvpDisplayStatus.cancelled);
      expect(card.statusLabel, 'Cancelled');
    });

    test('the host of a live Table is Going', () {
      final card = buildHomeTableCard(
        table: buildTestTableSummary(),
        isHost: true,
      );
      expect(card.displayStatus, RsvpDisplayStatus.going);
      expect(card.isHost, isTrue);
    });

    test('rsvp statuses map onto the 5-chip vocabulary', () {
      final byStatus = {
        for (final status in [
          RsvpStatus.confirmed,
          RsvpStatus.attended,
          RsvpStatus.requested,
          RsvpStatus.invited,
          RsvpStatus.waitlisted,
        ])
          status: buildHomeTableCard(
            table: buildTestTableSummary(),
            isHost: false,
            rsvpStatus: status,
          ),
      };
      expect(
        byStatus[RsvpStatus.confirmed]!.displayStatus,
        RsvpDisplayStatus.going,
      );
      expect(
        byStatus[RsvpStatus.attended]!.displayStatus,
        RsvpDisplayStatus.going,
      );
      expect(
        byStatus[RsvpStatus.requested]!.displayStatus,
        RsvpDisplayStatus.requested,
      );
      expect(
        byStatus[RsvpStatus.invited]!.displayStatus,
        RsvpDisplayStatus.requested,
      );
      expect(byStatus[RsvpStatus.invited]!.statusLabel, 'Invited');
      expect(
        byStatus[RsvpStatus.waitlisted]!.displayStatus,
        RsvpDisplayStatus.waitlisted,
      );
    });
  });

  group('sortHomeTableCards', () {
    test(
        'orders upcoming by soonest start, then happened, then rated, '
        'then cancelled', () {
      HomeTableCard card(String id, TableStatus status, DateTime start) {
        return buildHomeTableCard(
          table:
              buildTestTableSummary(id: id, status: status, startTime: start),
          isHost: false,
          rsvpStatus: RsvpStatus.confirmed,
        );
      }

      final sorted = sortHomeTableCards([
        card('cancelled', TableStatus.cancelled, DateTime(2026, 9)),
        card('later', TableStatus.filling, DateTime(2026, 9, 20)),
        card('rated', TableStatus.rated, DateTime(2026, 7)),
        card('soon', TableStatus.confirmed, DateTime(2026, 9, 10)),
        card('happened', TableStatus.happened, DateTime(2026, 7, 15)),
      ]);

      expect(
        [for (final c in sorted) c.table.id],
        ['soon', 'later', 'happened', 'rated', 'cancelled'],
      );
    });
  });

  group('HomeController.build', () {
    test(
        'merges hosted and rsvp Tables, resolves rsvp Table docs, and '
        'loads crews', () async {
      tablesRepository
        ..hostedTables = [
          buildTestTableSummary(id: 'hosted-1', hostId: 'me'),
        ]
        ..myRsvps = [
          MyRsvp(
            tableId: 'rsvp-1',
            status: RsvpStatus.waitlisted,
            createdAt: DateTime(2026, 8),
          ),
        ]
        ..tablesById['rsvp-1'] = buildTestTableSummary(id: 'rsvp-1');
      crewsRepository.myCrews = [
        const CrewSummary(id: 'crew-1', name: 'Coffee Crew', memberCount: 4),
      ];

      final data = await container.read(homeControllerProvider.future);

      expect(data.tables, hasLength(2));
      expect(
        data.tables.singleWhere((c) => c.table.id == 'hosted-1').isHost,
        isTrue,
      );
      expect(
        data.tables.singleWhere((c) => c.table.id == 'rsvp-1').displayStatus,
        RsvpDisplayStatus.waitlisted,
      );
      expect(data.crews.single.name, 'Coffee Crew');
    });

    test('skips an rsvp row whose Table no longer resolves', () async {
      tablesRepository.myRsvps = [
        MyRsvp(
          tableId: 'gone',
          status: RsvpStatus.confirmed,
          createdAt: DateTime(2026, 8),
        ),
      ];

      final data = await container.read(homeControllerProvider.future);

      expect(data.tables, isEmpty);
    });

    test('a hosted Table with a stray rsvp row keeps its host card', () async {
      tablesRepository
        ..hostedTables = [
          buildTestTableSummary(hostId: 'me'),
        ]
        ..myRsvps = [
          MyRsvp(
            tableId: 'table-1',
            status: RsvpStatus.waitlisted,
            createdAt: DateTime(2026, 8),
          ),
        ];

      final data = await container.read(homeControllerProvider.future);

      expect(data.tables.single.isHost, isTrue);
      expect(data.tables.single.displayStatus, RsvpDisplayStatus.going);
    });
  });
}
