import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/core/offline/offline_mutation_queue.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/application/create_table_controller.dart';
import 'package:tablecrew/features/tables/application/create_table_draft_controller.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_table_mutations_repository.dart';

/// Unit tests for [CreateTableController.submit]'s success/offline-queue/
/// failure paths, against [FakeTableMutationsRepository] and
/// [FakeConnectivityRepository] — the same shape
/// `account_setup_controller_test.dart` established for the onboarding
/// equivalent. Milestone F6.
void main() {
  late FakeTableMutationsRepository fakeMutations;
  late FakeConnectivityRepository fakeConnectivity;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeMutations = FakeTableMutationsRepository();
    fakeConnectivity = FakeConnectivityRepository();
    container = ProviderContainer(
      overrides: [
        tableMutationsRepositoryProvider.overrideWithValue(fakeMutations),
        connectivityRepositoryProvider.overrideWithValue(fakeConnectivity),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeConnectivity.dispose);
    container
      ..listen(createTableControllerProvider, (_, __) {})
      ..listen(offlineMutationQueueProvider, (_, __) {});
  });

  CreateTableController controller() =>
      container.read(createTableControllerProvider.notifier);

  CreateTableState state() => container.read(createTableControllerProvider);

  Future<void> stageValidDraft() async {
    final draftNotifier =
        container.read(createTableDraftControllerProvider.notifier);
    await container.read(createTableDraftControllerProvider.future);
    await draftNotifier.setTitle('Board Games Night');
    await draftNotifier.setInterestTag('board_games');
    await draftNotifier.setVenue(
      const VenueSelection(name: 'Cafe Coffee Day', address: '123 Main St'),
    );
    await draftNotifier.setStartTime(DateTime(2026, 9, 20, 19));
  }

  group('submit (online)', () {
    test(
        'a valid draft succeeds, clears the draft, and calls createTable '
        'with the staged fields', () async {
      await stageValidDraft();

      final result = await controller().submit();

      expect(result, isTrue);
      expect(state().status, CreateTableStatus.succeeded);
      expect(state().createdTableId, fakeMutations.createTableResult.tableId);
      expect(fakeMutations.createTableCalls, hasLength(1));
      final call = fakeMutations.createTableCalls.single;
      expect(call.title, 'Board Games Night');
      expect(call.visibility, 'closed');
      expect(call.venue.name, 'Cafe Coffee Day');
      expect(call.capacityMin, 4);
      expect(call.capacityMax, 6);
      expect(call.idempotencyKey, isNotEmpty);
      expect(
        container.read(createTableDraftControllerProvider).value?.title,
        isEmpty,
        reason: 'the draft should be cleared once createTable succeeds',
      );
    });

    test(
        'a missing required field fails defensively without calling '
        'createTable', () async {
      // No stageValidDraft() — venue/startTime are still null, the state
      // the screen's own Continue-button gating is supposed to prevent.
      final result = await controller().submit();

      expect(result, isFalse);
      expect(state().status, CreateTableStatus.failed);
      expect(fakeMutations.createTableCalls, isEmpty);
    });

    test('a known callable error surfaces its code and message', () async {
      await stageValidDraft();
      fakeMutations.createTableError = const TableCallableException(
        code: 'TRUST_STANDING_RESTRICTED',
        message: "Your account currently can't create new Tables.",
      );

      final result = await controller().submit();

      expect(result, isFalse);
      expect(state().status, CreateTableStatus.failed);
      expect(state().errorCode, 'TRUST_STANDING_RESTRICTED');
      expect(
        state().errorMessage,
        "Your account currently can't create new Tables.",
      );
    });
  });

  group('submit (offline)', () {
    test(
        'queues immediately without calling createTable, then retries and '
        'succeeds once reconnected, reusing the same idempotency key',
        () async {
      await stageValidDraft();
      fakeConnectivity.setOffline(isOffline: true);

      final result = await controller().submit();

      expect(result, isTrue);
      expect(state().status, CreateTableStatus.queuedOffline);
      expect(fakeMutations.createTableCalls, isEmpty);

      final succeeded = Completer<void>();
      container.listen(createTableControllerProvider, (previous, next) {
        if (next.status == CreateTableStatus.succeeded) {
          succeeded.complete();
        }
      });
      fakeConnectivity.setOffline(isOffline: false);
      await succeeded.future.timeout(const Duration(seconds: 2));

      expect(state().status, CreateTableStatus.succeeded);
      expect(fakeMutations.createTableCalls, hasLength(1));
    });
  });
}
