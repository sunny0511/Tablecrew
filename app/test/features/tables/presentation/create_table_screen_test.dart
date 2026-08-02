import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/presentation/create_table_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_table_mutations_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 10 (Create Table), Milestone F6.
void main() {
  late FakeTableMutationsRepository fakeMutations;
  late FakeConnectivityRepository connectivity;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeMutations = FakeTableMutationsRepository();
    connectivity = FakeConnectivityRepository();
    container = ProviderContainer(
      overrides: [
        tableMutationsRepositoryProvider.overrideWithValue(fakeMutations),
        connectivityRepositoryProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(connectivity.dispose);
  });

  Future<void> pumpScreen(WidgetTester tester, {String? crewId}) async {
    final router = buildTestRouter(
      initialPath: '/tables/create',
      initialName: 'create-table',
      initialScreen: CreateTableScreen(crewId: crewId),
      destinations: const {
        'invite': '/tables/:tableId/invite',
        'home': '/home',
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

  Future<void> fillVenue(WidgetTester tester) async {
    await tester.tap(find.text('Choose a venue'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Venue name'),
      'Cafe Coffee Day',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Address'),
      '123 Main St',
    );
    await tester.pump();
    await tester.tap(find.text('Use this venue'));
    await tester.pumpAndSettle();
  }

  Future<void> fillStartTime(WidgetTester tester) async {
    await tester.tap(find.text('Pick a date & time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  ElevatedButton createButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create Table'),
    );
  }

  testWidgets('renders the form with Create Table disabled', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Plan a Table'), findsWidgets);
    expect(find.text('Choose a venue'), findsOneWidget);
    expect(createButton(tester).onPressed, isNull);
  });

  testWidgets('selecting an activity updates the recommended headcount band',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('4'), findsOneWidget); // default band start
    expect(find.text('Recommended 2-8'), findsOneWidget);

    await tester.tap(find.text('Board Games'));
    await tester.pump();

    expect(find.text('6'), findsOneWidget);
    expect(find.text('Recommended 4-8'), findsOneWidget);
  });

  testWidgets('picking a venue via manual entry populates the venue field',
      (tester) async {
    await pumpScreen(tester);

    await fillVenue(tester);

    expect(find.text('Cafe Coffee Day'), findsOneWidget);
    expect(find.text('123 Main St'), findsOneWidget);
  });

  testWidgets('picking a date and time populates the start field', (
    tester,
  ) async {
    await pumpScreen(tester);

    await fillStartTime(tester);

    expect(find.text('Pick a date & time'), findsNothing);
  });

  testWidgets(
      'a complete form online creates the Table and routes to Invite & '
      'Share', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'What are you planning?'),
      'Board Games Night',
    );
    await tester.pump();
    await fillVenue(tester);
    await fillStartTime(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pumpAndSettle();

    expect(fakeMutations.createTableCalls, hasLength(1));
    expect(fakeMutations.createTableCalls.single.title, 'Board Games Night');
    expect(find.text('route:invite'), findsOneWidget);
  });

  testWidgets('a Crew-originated draft passes crewId through to createTable',
      (tester) async {
    await pumpScreen(tester, crewId: 'crew-42');

    await tester.enterText(
      find.widgetWithText(TextField, 'What are you planning?'),
      'Crew Dinner',
    );
    await tester.pump();
    await fillVenue(tester);
    await fillStartTime(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pumpAndSettle();

    expect(fakeMutations.createTableCalls.single.crewId, 'crew-42');
  });

  testWidgets('offline at submit time queues the Table and routes home', (
    tester,
  ) async {
    connectivity = FakeConnectivityRepository(initiallyOffline: true);
    container = ProviderContainer(
      overrides: [
        tableMutationsRepositoryProvider.overrideWithValue(fakeMutations),
        connectivityRepositoryProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(container.dispose);
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'What are you planning?'),
      'Board Games Night',
    );
    await tester.pump();
    await fillVenue(tester);
    await fillStartTime(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pumpAndSettle();

    expect(fakeMutations.createTableCalls, isEmpty);
    expect(find.text('route:home'), findsOneWidget);
  });

  testWidgets('a callable failure shows an inline error and stays on screen',
      (tester) async {
    fakeMutations.createTableError = const TableCallableException(
      code: 'TRUST_STANDING_RESTRICTED',
      message: "Your account currently can't create new Tables.",
    );
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'What are you planning?'),
      'Board Games Night',
    );
    await tester.pump();
    await fillVenue(tester);
    await fillStartTime(tester);

    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Table'));
    await tester.pumpAndSettle();

    expect(
      find.text("Your account currently can't create new Tables."),
      findsOneWidget,
    );
    expect(find.text('route:invite'), findsNothing);
  });
}
