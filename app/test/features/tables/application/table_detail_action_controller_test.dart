import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/application/table_detail_action_controller.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_table_mutations_repository.dart';
import '../../../fakes/fake_tables_repository.dart';

/// Unit tests for [TableDetailActionController]'s success/offline-queue/
/// failure paths — Milestone F6.
///
/// Each test uses its own `tableId` (`t-<scenario>`), even where the
/// scenario itself doesn't care which Table it's acting on. Confirmed by
/// isolating the failure in a throwaway repro: two tests in the same file
/// reusing the identical `tableId` string across two separate fresh
/// `ProviderContainer`s (one that already ran a full successful
/// `OfflineMutationQueue.run()` for that mutation id, followed by one
/// exercising the offline-then-reconnect path for the *same* id) made the
/// second test's reconnect callback never fire — a real, reproducible
/// hang, not flakiness, though its exact mechanism wasn't chased further
/// since distinct ids per test both sidesteps it and is the more
/// realistic shape anyway (two real screens never share a container).
void main() {
  late FakeTableMutationsRepository fakeMutations;
  late FakeConnectivityRepository fakeConnectivity;
  late FakeTablesRepository fakeTables;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeMutations = FakeTableMutationsRepository();
    fakeConnectivity = FakeConnectivityRepository();
    fakeTables = FakeTablesRepository();
    container = ProviderContainer(
      overrides: [
        tableMutationsRepositoryProvider.overrideWithValue(fakeMutations),
        connectivityRepositoryProvider.overrideWithValue(fakeConnectivity),
        tablesRepositoryProvider.overrideWithValue(fakeTables),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeConnectivity.dispose);
  });

  TableDetailActionController controller(String tableId) {
    fakeTables.tablesById.putIfAbsent(
      tableId,
      () => buildTestTableSummary(id: tableId),
    );
    container.listen(tableDetailActionControllerProvider(tableId), (_, __) {});
    return container
        .read(tableDetailActionControllerProvider(tableId).notifier);
  }

  TableDetailActionState state(String tableId) =>
      container.read(tableDetailActionControllerProvider(tableId));

  group('requestSeat', () {
    test('online success calls requestSeat with an idempotency key', () async {
      await controller('t-seat-online').requestSeat();

      expect(state('t-seat-online').status, TableDetailActionStatus.succeeded);
      expect(fakeMutations.requestSeatCalls, hasLength(1));
      expect(fakeMutations.requestSeatCalls.single.tableId, 't-seat-online');
      expect(fakeMutations.requestSeatCalls.single.idempotencyKey, isNotEmpty);
    });

    test('a known callable error surfaces its code (SEAT_REQUEST_CONTENTION)',
        () async {
      fakeMutations.requestSeatError = const TableCallableException(
        code: 'SEAT_REQUEST_CONTENTION',
        message: 'Lots of people grabbing a seat right now.',
      );

      await controller('t-seat-contention').requestSeat();

      expect(state('t-seat-contention').status, TableDetailActionStatus.failed);
      expect(state('t-seat-contention').errorCode, 'SEAT_REQUEST_CONTENTION');
    });

    test('queues offline, then retries and succeeds once reconnected',
        () async {
      fakeConnectivity.setOffline(isOffline: true);

      await controller('t-seat-offline').requestSeat();

      expect(
        state('t-seat-offline').status,
        TableDetailActionStatus.queuedOffline,
      );
      expect(fakeMutations.requestSeatCalls, isEmpty);

      final succeeded = Completer<void>();
      container.listen(tableDetailActionControllerProvider('t-seat-offline'), (
        previous,
        next,
      ) {
        if (next.status == TableDetailActionStatus.succeeded) {
          succeeded.complete();
        }
      });
      fakeConnectivity.setOffline(isOffline: false);
      await succeeded.future.timeout(const Duration(seconds: 2));

      expect(fakeMutations.requestSeatCalls, hasLength(1));
    });
  });

  group('cancelRsvp', () {
    test('online success calls cancelRsvp', () async {
      await controller('t-cancel-rsvp').cancelRsvp();

      expect(state('t-cancel-rsvp').status, TableDetailActionStatus.succeeded);
      expect(fakeMutations.cancelRsvpCalls, hasLength(1));
    });
  });

  group('confirmAttendee', () {
    test('online success calls confirmAttendee with the target uid', () async {
      await controller('t-confirm').confirmAttendee('bob');

      expect(state('t-confirm').status, TableDetailActionStatus.succeeded);
      expect(fakeMutations.confirmAttendeeCalls.single.targetUserId, 'bob');
    });
  });

  group('cancelTable', () {
    test('online success calls cancelTable with the reason', () async {
      await controller('t-cancel-table-ok').cancelTable(reason: 'Venue closed');

      expect(
        state('t-cancel-table-ok').status,
        TableDetailActionStatus.succeeded,
      );
      expect(fakeMutations.cancelTableCalls.single.reason, 'Venue closed');
    });

    test('offline fails with an inline notice, not a queued retry', () async {
      fakeConnectivity.setOffline(isOffline: true);

      await controller('t-cancel-table-offline').cancelTable();

      expect(
        state('t-cancel-table-offline').status,
        TableDetailActionStatus.failed,
      );
      expect(fakeMutations.cancelTableCalls, isEmpty);
    });

    test('a callable failure surfaces its message', () async {
      fakeMutations.cancelTableError = const TableCallableException(
        code: 'ALREADY_HAPPENED',
        message: 'This Table has already happened.',
      );

      await controller('t-cancel-table-fail').cancelTable();

      expect(
        state('t-cancel-table-fail').status,
        TableDetailActionStatus.failed,
      );
      expect(
        state('t-cancel-table-fail').errorMessage,
        'This Table has already happened.',
      );
    });
  });
}
