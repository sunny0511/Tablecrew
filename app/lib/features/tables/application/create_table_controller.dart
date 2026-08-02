import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/core/offline/offline_mutation_queue.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/application/create_table_draft_controller.dart';

part 'create_table_controller.g.dart';

/// [CreateTableController]'s lifecycle states.
enum CreateTableStatus {
  /// Nothing submitted yet.
  idle,

  /// A `createTable` call is in flight.
  submitting,

  /// Offline at submit time — the draft is a local "Draft — will send when
  /// back online" Table (Screen 10's Offline Behavior), auto-retried on
  /// reconnect with the same idempotency key.
  queuedOffline,

  /// `createTable` succeeded — [CreateTableState.createdTableId] is set.
  succeeded,

  /// A real, non-connectivity failure — see [CreateTableState.errorCode].
  failed,
}

/// [CreateTableController]'s state.
class CreateTableState {
  /// Creates a state, defaulting to idle.
  const CreateTableState({
    this.status = CreateTableStatus.idle,
    this.createdTableId,
    this.errorCode,
    this.errorMessage,
  });

  /// The current status.
  final CreateTableStatus status;

  /// The created Table's id once [status] is [CreateTableStatus.succeeded].
  final String? createdTableId;

  /// The app-specific error code when [status] is
  /// [CreateTableStatus.failed] (e.g. `TRUST_STANDING_RESTRICTED`).
  final String? errorCode;

  /// A human-readable message when [status] is [CreateTableStatus.failed].
  final String? errorMessage;
}

/// Drives Screen 10's "Create Table" submission: validates nothing itself
/// (the widget gates the button on the draft's completeness; the server
/// re-validates everything), runs `createTable` through
/// [OfflineMutationQueue] with the draft's own `draftId` as the mutation
/// id, and implements the offline path — queue, then auto-retry once on
/// reconnect (docs/API_SPEC.md §2's same-key retry contract makes the
/// retry safe even if it races a slow first attempt).
///
/// `keepAlive: true`: like `AccountSetupController`, the user can navigate
/// away from Create Table after an offline queue, and the reconnect retry
/// plus this state must outlive the screen.
///
/// Added Milestone F6.
@Riverpod(keepAlive: true)
class CreateTableController extends _$CreateTableController {
  StreamSubscription<void>? _reconnectSubscription;

  @override
  CreateTableState build() {
    ref.onDispose(() => unawaited(_reconnectSubscription?.cancel()));
    return const CreateTableState();
  }

  /// Submits the current draft. Returns `true` when the caller should
  /// navigate onward (created, or safely queued offline); `false` on a
  /// real failure (inspect [state]).
  Future<bool> submit() async {
    state = const CreateTableState(status: CreateTableStatus.submitting);
    return _attempt();
  }

  Future<bool> _attempt() async {
    final draft = await ref.read(createTableDraftControllerProvider.future);
    final venue = draft.venue;
    final startTime = draft.startTime;
    if (draft.title.trim().isEmpty || venue == null || startTime == null) {
      // The widget's gating should make this unreachable — defensive, same
      // pattern as AccountSetupController's missing-field guard.
      state = const CreateTableState(
        status: CreateTableStatus.failed,
        errorMessage: 'Missing required Table details.',
      );
      return false;
    }
    final headcount =
        draft.headcount ?? recommendedHeadcountFor(draft.interestTag).start;

    // The queue's `late` fields (key store, connectivity subscription) are
    // set inside its own async `build()` — reading `.notifier` alone
    // doesn't wait for that to finish, so a call racing ahead of it hits
    // `LateInitializationError`. Awaiting the plain (non-`.notifier`)
    // provider first guarantees `build()` has actually completed.
    await ref.read(offlineMutationQueueProvider.future);
    final queue = ref.read(offlineMutationQueueProvider.notifier);
    try {
      final result = await queue.run(
        mutationId: draft.draftId,
        call: (idempotencyKey) =>
            ref.read(tableMutationsRepositoryProvider).createTable(
                  title: draft.title.trim(),
                  // F6 scope: Crew-only/Closed Tables only — the
                  // Open/Discover visibility branch is Milestone F7's
                  // (docs/IMPLEMENTATION_PLAN.md §4), and the widget's
                  // visibility control doesn't offer it yet.
                  visibility: 'closed',
                  venue: venue,
                  startTime: startTime,
                  // docs/DATABASE.md §3.2's capacity model wants min and
                  // max; Screen 10's single stepper sets one headcount, so
                  // min rides the activity band's floor and max is the
                  // chosen headcount.
                  capacityMin: recommendedHeadcountFor(draft.interestTag).min,
                  capacityMax: headcount,
                  idempotencyKey: idempotencyKey,
                  interestTag: draft.interestTag,
                  crewId: draft.crewId,
                ),
      );
      await ref.read(createTableDraftControllerProvider.notifier).clear();
      state = CreateTableState(
        status: CreateTableStatus.succeeded,
        createdTableId: result.tableId,
      );
      return true;
    } on OfflineMutationQueuedException {
      state = const CreateTableState(status: CreateTableStatus.queuedOffline);
      _retryOnReconnect();
      return true;
    } on TableCallableException catch (e) {
      state = CreateTableState(
        status: CreateTableStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
      return false;
    }
  }

  void _retryOnReconnect() {
    unawaited(_reconnectSubscription?.cancel());
    final queue = ref.read(offlineMutationQueueProvider.notifier);
    _reconnectSubscription = queue.reconnected.listen((_) {
      unawaited(_reconnectSubscription?.cancel());
      unawaited(_attempt());
    });
  }
}
