import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/presentation/table_detail_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_table_mutations_repository.dart';
import '../../../fakes/fake_tables_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 13 (Table Detail), Milestone F6.
void main() {
  late FakeTablesRepository fakeTables;
  late FakeTableMutationsRepository fakeMutations;
  late FakeConnectivityRepository fakeConnectivity;
  late ProviderContainer container;

  const tableId = 't1';
  final farFuture = DateTime.now().add(const Duration(days: 30));

  ProviderContainer buildContainer({String? uid = 'me'}) {
    final built = ProviderContainer(
      overrides: [
        tablesRepositoryProvider.overrideWithValue(fakeTables),
        tableMutationsRepositoryProvider.overrideWithValue(fakeMutations),
        connectivityRepositoryProvider.overrideWithValue(fakeConnectivity),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    // OfflineMutationQueue.build() awaits SharedPreferences.getInstance()
    // — without this mock it hangs indefinitely on the real platform
    // channel under a plain flutter test, which is what every action-
    // triggering test in this file (requestSeat/cancelRsvp/confirmAttendee
    // all go through the queue) needs to avoid.
    SharedPreferences.setMockInitialValues({});
    fakeTables = FakeTablesRepository();
    fakeMutations = FakeTableMutationsRepository();
    fakeConnectivity = FakeConnectivityRepository();
    addTearDown(fakeConnectivity.dispose);
    container = buildContainer();
  });

  /// A bounded stand-in for `pumpAndSettle()`: every successful action on
  /// this screen shows a `SnackBar` via `ref.listen` (`TableDetailScreen`
  /// itself), and a `SnackBar`'s default multi-second visible duration
  /// combined with `SkeletonPulse`'s `repeat(reverse: true)` animation
  /// during the brief "acting" state means `pumpAndSettle()` (which waits
  /// for *no* pending frames) reliably times out here — the same
  /// structural issue already documented in `otp_screen_test.dart` and
  /// `profile_setup_screen_test.dart`, confirmed again against this
  /// file's first run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/tables/$tableId',
      initialName: 'table-detail',
      initialScreen: const TableDetailScreen(tableId: tableId),
      destinations: const {
        'invite': '/tables/:tableId/invite',
        'report': '/report',
        'block': '/block',
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('host sees the attendee list and no primary action', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    fakeTables.attendeesByTableId[tableId] = const [
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.requested,
      ),
    ];
    await pumpScreen(tester);

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Request to Join'), findsNothing);
    expect(find.text('Cancel RSVP'), findsNothing);
  });

  testWidgets('host with zero attendees sees the empty state', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    await pumpScreen(tester);

    expect(find.text("Nobody's joined yet"), findsOneWidget);
  });

  testWidgets(
      'host tapping Confirm on a Requested attendee calls '
      'confirmAttendee', (tester) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    fakeTables.attendeesByTableId[tableId] = const [
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.requested,
      ),
    ];
    await pumpScreen(tester);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Confirm'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
    await settle(tester);

    expect(fakeMutations.confirmAttendeeCalls.single.targetUserId, 'bob');
  });

  testWidgets(
      'attendee row overflow: Report routes to Screen 27 with the '
      'attendee as a user target', (tester) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    fakeTables.attendeesByTableId[tableId] = const [
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.confirmed,
      ),
    ];
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('More actions for Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'route:report?targetType=user&targetId=bob&targetDisplayName=Bob',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      "attendee row overflow: Block routes to Screen 28 with the Table's "
      'crewId reflected as sharesCrew', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      hostId: 'me',
      startTime: farFuture,
      crewId: 'crew-1',
    );
    fakeTables.attendeesByTableId[tableId] = const [
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.confirmed,
      ),
    ];
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('More actions for Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'route:block?targetUserId=bob&targetDisplayName=Bob&sharesCrew=true',
      ),
      findsOneWidget,
    );
  });

  testWidgets("attendee row overflow is hidden on the current user's own row", (
    tester,
  ) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    fakeTables.attendeesByTableId[tableId] = const [
      AttendeeSummary(
        uid: 'me',
        displayName: 'Me',
        status: RsvpStatus.confirmed,
      ),
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.confirmed,
      ),
    ];
    await pumpScreen(tester);

    expect(find.byTooltip('More actions for Me'), findsNothing);
    expect(find.byTooltip('More actions for Bob'), findsOneWidget);
  });

  testWidgets('host overflow: Invite more people routes to Invite & Share', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    await pumpScreen(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite more people'));
    await tester.pumpAndSettle();

    expect(find.text('route:invite'), findsOneWidget);
  });

  testWidgets(
      'host overflow: Cancel Table requires a reason, then calls '
      'cancelTable', (tester) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, hostId: 'me', startTime: farFuture);
    await pumpScreen(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Table'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel Table'))
          .onPressed,
      isNull,
      reason: 'a reason is required before the dialog can confirm',
    );

    await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Rain');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel Table'));
    await settle(tester);

    expect(fakeMutations.cancelTableCalls.single.reason, 'Rain');
  });

  testWidgets(
      'a non-host with no rsvp sees Request to Join, which calls '
      'requestSeat', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      startTime: farFuture,
    );
    await pumpScreen(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Request to Join'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Request to Join'));
    await settle(tester);

    expect(fakeMutations.requestSeatCalls, hasLength(1));
  });

  testWidgets(
      'a non-host attendee sees their own status chip, not the full '
      'attendee list', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      startTime: farFuture,
    );
    fakeTables.myRsvpStatusByTableId[tableId] = RsvpStatus.waitlisted;
    await pumpScreen(tester);

    expect(find.text('Waitlisted'), findsOneWidget);
  });

  testWidgets(
      'cancelling an RSVP far from start time skips the confirmation '
      'dialog', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      startTime: farFuture,
    );
    fakeTables.myRsvpStatusByTableId[tableId] = RsvpStatus.confirmed;
    await pumpScreen(tester);

    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'Cancel RSVP'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel RSVP'));
    await settle(tester);

    expect(fakeMutations.cancelRsvpCalls, hasLength(1));
    expect(find.text('Cancel your RSVP?'), findsNothing);
  });

  testWidgets(
      'cancelling an RSVP within 2 hours of start shows a confirmation '
      'dialog', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      startTime: DateTime.now().add(const Duration(minutes: 30)),
    );
    fakeTables.myRsvpStatusByTableId[tableId] = RsvpStatus.confirmed;
    await pumpScreen(tester);

    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'Cancel RSVP'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel RSVP'));
    await settle(tester);

    expect(find.text('Cancel your RSVP?'), findsOneWidget);
    expect(fakeMutations.cancelRsvpCalls, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel RSVP'));
    await settle(tester);

    expect(fakeMutations.cancelRsvpCalls, hasLength(1));
  });

  testWidgets('SEAT_REQUEST_CONTENTION shows its own distinct notice', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(
      id: tableId,
      startTime: farFuture,
    );
    fakeMutations.requestSeatError = const TableCallableException(
      code: 'SEAT_REQUEST_CONTENTION',
      message: 'Lots of people grabbing a seat right now — try again in a '
          'second.',
    );
    await pumpScreen(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Request to Join'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Request to Join'));
    await settle(tester);

    expect(
      find.text(
        'Lots of people grabbing a seat right now — try again in a second.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Request to Join'),
          )
          .onPressed,
      isNotNull,
      reason: 'contention re-enables the button immediately for a retry',
    );
  });

  testWidgets('a load failure shows an error notice', (tester) async {
    // No fakeTables.tablesById entry for this id -> fetchTable returns
    // null -> TableDetailController.build throws.
    await pumpScreen(tester);

    expect(find.text("Couldn't load this Table."), findsOneWidget);
  });
}
