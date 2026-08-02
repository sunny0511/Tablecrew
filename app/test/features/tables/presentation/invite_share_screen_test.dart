import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/presentation/invite_share_screen.dart';

import '../../../fakes/fake_crews_repository.dart';
import '../../../fakes/fake_tables_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 12 (Invite & Share Sheet), Milestone F6 —
/// Crew-only/link-copy-only scope (see the screen's own doc comment).
void main() {
  late FakeTablesRepository fakeTables;
  late FakeCrewsRepository fakeCrews;
  late ProviderContainer container;

  const tableId = 't1';

  setUp(() {
    fakeTables = FakeTablesRepository();
    fakeCrews = FakeCrewsRepository();
    container = ProviderContainer(
      overrides: [
        tablesRepositoryProvider.overrideWithValue(fakeTables),
        crewsRepositoryProvider.overrideWithValue(fakeCrews),
      ],
    );
    addTearDown(container.dispose);

    // `Clipboard.setData`'s platform-channel call otherwise never
    // resolves under a plain `flutter test` in this environment (no
    // default mock handler observed for `SystemChannels.platform` here,
    // unlike the usual `flutter_test` behavior) — mocked explicitly,
    // same convention as this codebase's other unmockable-by-default
    // plugin channels (`FakeImagePickerPlatform`,
    // `FakePermissionHandlerPlatform`).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/tables/$tableId/invite',
      initialName: 'invite',
      initialScreen: const InviteShareScreen(tableId: tableId),
      destinations: const {'table-detail': '/tables/:tableId'},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Table with no crewId shows the No Crew yet empty state', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(id: tableId);
    await pumpScreen(tester);

    expect(find.text('No Crew yet'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
      'a Table with a Crew shows the real member roster, with Send '
      'invites disabled', (tester) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, crewId: 'crew-1');
    fakeCrews.crewMembersByCrewId['crew-1'] = const [
      CrewMember(uid: 'bob', displayName: 'Bob'),
      CrewMember(uid: 'carol', displayName: 'Carol'),
    ];
    await pumpScreen(tester);

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Send invites'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining("isn't wired up yet"),
      findsOneWidget,
    );
  });

  testWidgets('checking a Crew member toggles its checkbox state', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] =
        buildTestTableSummary(id: tableId, crewId: 'crew-1');
    fakeCrews.crewMembersByCrewId['crew-1'] = const [
      CrewMember(uid: 'bob', displayName: 'Bob'),
    ];
    await pumpScreen(tester);

    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });

  testWidgets('Copy link copies to the clipboard and shows a confirmation', (
    tester,
  ) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(id: tableId);
    await pumpScreen(tester);

    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'Copy link'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy link'));
    // A bounded stand-in for pumpAndSettle(): the confirmation SnackBar's
    // default multi-second visible duration means pumpAndSettle() (which
    // waits for no pending frames) times out here — same class of issue
    // documented in otp_screen_test.dart/table_detail_screen_test.dart.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Copied!'), findsOneWidget);
  });

  testWidgets('Done routes back to Table Detail', (tester) async {
    fakeTables.tablesById[tableId] = buildTestTableSummary(id: tableId);
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('route:table-detail'), findsOneWidget);
  });

  testWidgets('a load failure shows an error notice', (tester) async {
    // No fakeTables.tablesById entry -> fetchTable resolves null ->
    // inviteShareData throws.
    await pumpScreen(tester);

    expect(find.text("Couldn't load this Table."), findsOneWidget);
  });
}
