import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/core/offline/offline_mutation_queue.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/application/table_detail_controller.dart';

part 'table_detail_action_controller.g.dart';

/// [TableDetailActionController]'s lifecycle states.
enum TableDetailActionStatus {
  /// Nothing in flight.
  idle,

  /// A callable is in flight.
  acting,

  /// Offline at call time — queued via `OfflineMutationQueue`, auto-retried
  /// on reconnect (`requestSeat`/`cancelRsvp`/`confirmAttendee` only; see
  /// [TableDetailActionController.cancelTable]'s doc comment for why that
  /// one isn't queued).
  queuedOffline,

  /// The most recent action succeeded.
  succeeded,

  /// A real, non-connectivity failure.
  failed,
}

/// [TableDetailActionController]'s state.
class TableDetailActionState {
  /// Creates a state, defaulting to idle.
  const TableDetailActionState({
    this.status = TableDetailActionStatus.idle,
    this.errorCode,
    this.errorMessage,
  });

  /// The current status.
  final TableDetailActionStatus status;

  /// The app-specific error code when [status] is
  /// [TableDetailActionStatus.failed] (e.g. `SEAT_REQUEST_CONTENTION` —
  /// Screen 13's Validation Rules give this one its own distinct, non-
  /// "Table is full" copy; the widget checks for it specifically).
  final String? errorCode;

  /// A human-readable message when [status] is
  /// [TableDetailActionStatus.failed].
  final String? errorMessage;
}

/// Drives Table Detail (Screen 13)'s mutating actions — `requestSeat`,
/// `cancelRsvp`, `confirmAttendee` (host approving a Requested attendee),
/// and `cancelTable` — against [TableMutationsRepository], separate from
/// the read-only `TableDetailController` the same way Create Table splits
/// its draft controller from its submit controller. On success, invalidates
/// `TableDetailController` for the same `tableId` so the screen's data
/// (RSVP status, attendee list, capacity counts) reflects the mutation
/// immediately rather than waiting for a manual pull-to-refresh.
///
/// `keepAlive: true`: like `CreateTableController`, a queued-offline
/// `requestSeat`/`cancelRsvp` must keep retrying via its `reconnected`
/// subscription even if the user navigates off Table Detail before
/// reconnecting.
///
/// Added Milestone F6.
@Riverpod(keepAlive: true)
class TableDetailActionController extends _$TableDetailActionController {
  StreamSubscription<void>? _reconnectSubscription;

  @override
  TableDetailActionState build(String tableId) {
    ref.onDispose(() => unawaited(_reconnectSubscription?.cancel()));
    return const TableDetailActionState();
  }

  /// Screen 13's non-attendee primary action ("Request Seat"/"Request to
  /// Join"). No client-side capacity gating for this F6-scope Closed-only
  /// Table: `requestSeat`'s server logic checks `visibility == 'closed'`
  /// before capacity at all, so every request lands as `"requested"`,
  /// pending the host's [confirmAttendee] — the spec's "Table is full ->
  /// Join Waitlist" client behavior is specific to Open Tables, deferred
  /// to Milestone F7 alongside the whole Open/Discover visibility branch.
  Future<void> requestSeat() {
    return _runQueued(
      mutationId: 'requestSeat:$tableId',
      call: (key) => ref
          .read(tableMutationsRepositoryProvider)
          .requestSeat(tableId: tableId, idempotencyKey: key),
    );
  }

  /// Screen 13's attendee primary action ("Cancel RSVP"). The <2h
  /// confirmation-dialog decision is the widget's job (it has the Table's
  /// `startTime`); this method only performs the call once confirmed.
  Future<void> cancelRsvp() {
    return _runQueued(
      mutationId: 'cancelRsvp:$tableId',
      call: (key) => ref
          .read(tableMutationsRepositoryProvider)
          .cancelRsvp(tableId: tableId, idempotencyKey: key),
    );
  }

  /// The host's inline action on a Requested attendee row.
  Future<void> confirmAttendee(String targetUserId) {
    return _runQueued(
      mutationId: 'confirmAttendee:$tableId:$targetUserId',
      call: (key) => ref.read(tableMutationsRepositoryProvider).confirmAttendee(
            tableId: tableId,
            targetUserId: targetUserId,
            idempotencyKey: key,
          ),
    );
  }

  /// The host's overflow-menu action. Unlike the three actions above,
  /// `cancelTable`'s request contract has no `idempotencyKey` field at all
  /// (docs/API_SPEC.md §3.1 — it's idempotent by construction via the
  /// Table's own `status`, not a client-supplied key), and Screen 13's
  /// Offline Behavior section only specifies queue-and-retry for
  /// `requestSeat`/`cancelRsvp`. So this checks connectivity directly
  /// rather than going through `OfflineMutationQueue`, and simply fails
  /// with an inline offline notice rather than queuing — a real user can
  /// just retry "Cancel Table" once back online, and the server-side
  /// idempotency means that retry is always safe.
  Future<void> cancelTable({String? reason}) async {
    state =
        const TableDetailActionState(status: TableDetailActionStatus.acting);
    final connectivity = ref.read(connectivityRepositoryProvider);
    if (await connectivity.isOffline()) {
      state = const TableDetailActionState(
        status: TableDetailActionStatus.failed,
        errorMessage: "You're offline — try cancelling again once "
            'reconnected.',
      );
      return;
    }
    try {
      await ref
          .read(tableMutationsRepositoryProvider)
          .cancelTable(tableId: tableId, reason: reason);
      ref.invalidate(tableDetailControllerProvider(tableId));
      state = const TableDetailActionState(
        status: TableDetailActionStatus.succeeded,
      );
    } on TableCallableException catch (e) {
      state = TableDetailActionState(
        status: TableDetailActionStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
    }
  }

  Future<void> _runQueued({
    required String mutationId,
    required Future<void> Function(String idempotencyKey) call,
  }) async {
    state =
        const TableDetailActionState(status: TableDetailActionStatus.acting);
    // See CreateTableController's identical await for why this is needed:
    // OfflineMutationQueue's `late` fields are set inside its own async
    // `build()`, which reading `.notifier` alone doesn't wait for.
    await ref.read(offlineMutationQueueProvider.future);
    final queue = ref.read(offlineMutationQueueProvider.notifier);
    try {
      await queue.run(mutationId: mutationId, call: call);
      ref.invalidate(tableDetailControllerProvider(tableId));
      state = const TableDetailActionState(
        status: TableDetailActionStatus.succeeded,
      );
    } on OfflineMutationQueuedException {
      state = const TableDetailActionState(
        status: TableDetailActionStatus.queuedOffline,
      );
      _retryOnReconnect(mutationId: mutationId, call: call);
    } on TableCallableException catch (e) {
      state = TableDetailActionState(
        status: TableDetailActionStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
    }
  }

  void _retryOnReconnect({
    required String mutationId,
    required Future<void> Function(String idempotencyKey) call,
  }) {
    unawaited(_reconnectSubscription?.cancel());
    final queue = ref.read(offlineMutationQueueProvider.notifier);
    _reconnectSubscription = queue.reconnected.listen((_) {
      unawaited(_reconnectSubscription?.cancel());
      unawaited(_runQueued(mutationId: mutationId, call: call));
    });
  }
}
