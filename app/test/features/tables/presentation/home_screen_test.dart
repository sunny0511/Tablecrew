import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/presentation/home_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_crews_repository.dart';
import '../../../fakes/fake_tables_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 9 (Home / My Tables), Milestone F6.
void main() {
  late FakeTablesRepository tablesRepository;
  late FakeCrewsRepository crewsRepository;
  late FakeConnectivityRepository connectivity;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    final built = ProviderContainer(
      overrides: [
        tablesRepositoryProvider.overrideWithValue(tablesRepository),
        crewsRepositoryProvider.overrideWithValue(crewsRepository),
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        currentUidProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    tablesRepository = FakeTablesRepository();
    crewsRepository = FakeCrewsRepository();
    connectivity = FakeConnectivityRepository();
    addTearDown(connectivity.dispose);
    container = buildContainer();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/home',
      initialName: 'home',
      initialScreen: const HomeScreen(),
      destinations: const {
        'create-table': '/tables/create',
        'table-detail': '/tables/:tableId',
        'crew-detail': '/crews/:crewId',
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Tables empty state for a brand-new user', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Your first Table starts here'), findsOneWidget);
    expect(find.text('Create a Table or find one on Discover'), findsOneWidget);
  });

  testWidgets('renders a Table card with title, venue, and status chip', (
    tester,
  ) async {
    tablesRepository.hostedTables = [
      buildTestTableSummary(
        id: 't1',
        hostId: 'me',
        title: 'Founder Dinner',
        venueName: 'Broadway Cafe',
        confirmedCount: 3,
      ),
    ];
    await pumpScreen(tester);

    expect(find.text('Founder Dinner'), findsOneWidget);
    expect(find.textContaining('Broadway Cafe'), findsOneWidget);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('3 of 6 going'), findsOneWidget);
  });

  testWidgets('a cancelled Table renders the Cancelled chip', (tester) async {
    tablesRepository
      ..myRsvps = [
        MyRsvp(
          tableId: 't1',
          status: RsvpStatus.confirmed,
          createdAt: DateTime(2026, 8),
        ),
      ]
      ..tablesById['t1'] = buildTestTableSummary(
        id: 't1',
        status: TableStatus.cancelled,
      );
    await pumpScreen(tester);

    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('switching segments shows My Crews with its empty state', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('My Crews'));
    await tester.pumpAndSettle();

    expect(find.text('No Crews yet'), findsOneWidget);
  });

  testWidgets('a Crew card renders and Schedule a Table routes to create',
      (tester) async {
    crewsRepository.myCrews = [
      const CrewSummary(id: 'c1', name: 'Coffee Crew', memberCount: 4),
    ];
    await pumpScreen(tester);

    await tester.tap(find.text('My Crews'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee Crew'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);

    await tester.tap(find.text('Schedule a Table'));
    await tester.pumpAndSettle();

    expect(find.text('route:create-table'), findsOneWidget);
  });

  testWidgets('tapping a Table card routes to its Table Detail', (
    tester,
  ) async {
    tablesRepository.hostedTables = [
      buildTestTableSummary(id: 't1', hostId: 'me', title: 'Founder Dinner'),
    ];
    await pumpScreen(tester);

    await tester.tap(find.text('Founder Dinner'));
    await tester.pumpAndSettle();

    expect(find.text('route:table-detail'), findsOneWidget);
  });

  testWidgets('the FAB routes to Create Table', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('route:create-table'), findsOneWidget);
  });

  testWidgets('offline shows the saved-Tables banner', (tester) async {
    connectivity = FakeConnectivityRepository(initiallyOffline: true);
    addTearDown(connectivity.dispose);
    container = buildContainer();
    await pumpScreen(tester);

    expect(find.text('Offline — showing saved Tables'), findsOneWidget);
  });

  testWidgets('a load failure shows the pull-to-retry notice', (
    tester,
  ) async {
    tablesRepository.fetchError = Exception('backend down');
    await pumpScreen(tester);

    expect(
      find.text("Couldn't load your Tables — pull to retry."),
      findsOneWidget,
    );
  });
}
