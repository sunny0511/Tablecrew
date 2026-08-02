import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/core/offline/idempotency_key_store.dart';
import 'package:tablecrew/data/connectivity_repository.dart';

part 'offline_mutation_queue.g.dart';

/// Thrown by [OfflineMutationQueue.run] when the device is offline at call
/// time, instead of letting the callable's own SDK time out. The
/// [idempotencyKey] is already persisted by this point, so the caller (or
/// a listener on [OfflineMutationQueue.reconnected]) can retry the same
/// logical action later using [mutationId] and it will resolve to the same
/// key.
class OfflineMutationQueuedException implements Exception {
  /// Creates an exception carrying the [mutationId] and already-persisted
  /// [idempotencyKey] for the queued mutation.
  const OfflineMutationQueuedException({
    required this.mutationId,
    required this.idempotencyKey,
  });

  /// The caller-chosen identifier for this logical action instance.
  final String mutationId;

  /// The persisted idempotency key a retry of this same action must reuse.
  final String idempotencyKey;

  @override
  String toString() =>
      'OfflineMutationQueuedException(mutationId: $mutationId, '
      'idempotencyKey: $idempotencyKey)';
}

/// Recommendation R1: a single, reusable `core/` abstraction for every
/// idempotency-keyed callable (Table creation, Crew creation, ratings, and
/// later payments — docs/IMPLEMENTATION_PLAN.md's R1 text), so those
/// features don't each hand-roll a slightly different retry/persistence
/// scheme.
///
/// What this class owns: generating and persisting the idempotency key for
/// a logical action before the first attempt (docs/API_SPEC.md §2), gating
/// attempts on a real connectivity check instead of letting a doomed call
/// time out, keeping the key reserved across any failure (not just
/// connectivity ones — see [run]'s doc comment for why), and exposing
/// which mutations are currently pending plus a [reconnected] signal.
///
/// What this class deliberately does *not* own: automatically re-invoking
/// a failed call once connectivity returns. A Dart closure can't be
/// serialized to disk, so nothing survives an app restart except the
/// idempotency-key mapping itself — replaying the *call* (e.g.
/// re-submitting a Create-Table form) requires the feature layer's own
/// draft data, which only that feature knows how to rehydrate. The
/// intended pattern for feature code (starting Milestone F6/F7, per
/// `features/tables/README.md` and `features/crews/README.md`) is: call
/// [run] with a stable `mutationId`; on [OfflineMutationQueuedException],
/// keep the draft in local form state and show "will send when back
/// online"; listen to [reconnected] and call [run] again with the same
/// `mutationId` — the underlying store hands back the same key
/// automatically.
/// `keepAlive: true`, not the `@riverpod` autoDispose default — a real bug
/// found while wiring this class's first real feature consumer
/// (`CreateTableController`, Milestone F6). Every real call site only ever
/// `ref.read`s this provider (`run`/`release`/`reconnected` are all
/// accessed via `.notifier`, and nothing anywhere `ref.watch`es it), which
/// per Riverpod's own docs means no listener is ever registered — an
/// autoDispose provider with zero listeners for a full frame has its
/// state destroyed. Confirmed via a real `flutter test` run:
/// `CreateTableController.submit()`'s `await
/// ref.read(offlineMutationQueueProvider.future)` (needed to avoid a
/// separate `LateInitializationError` — see that await's own comment)
/// left just enough of a gap for the provider to be disposed before the
/// very next line read `.notifier`, throwing `UnmountedRefException`.
/// Exactly the same bug class this codebase has already hit twice —
/// `SplashScreen`'s autoDispose-during-loading crash (Milestone F5 task
/// #95) and `OnboardingProfileDraftController`'s silent mid-onboarding
/// reset (task #96) — and the fix is the same: `keepAlive: true`. It also
/// matches this class's own doc comment's stated intent ("exposes ...
/// pending-mutation state" for, e.g., a background sync banner) — that
/// can't work if the provider doesn't outlive whichever screen last read
/// it.
@Riverpod(keepAlive: true)
class OfflineMutationQueue extends _$OfflineMutationQueue {
  late IdempotencyKeyStore _keyStore;
  late ConnectivityRepository _connectivity;
  StreamController<void>? _reconnectedController;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _wasOffline = false;

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _keyStore = IdempotencyKeyStore(prefs);
    // Milestone F6: reconciled from a raw `Connectivity()` construction
    // onto `ConnectivityRepository` — the same untestable-under-plain-
    // `flutter test` pattern task #96 already fixed in the onboarding
    // screens and `AccountSetupController`; this class was the last
    // holdout, caught when Create Table's controller (the first real
    // feature consumer of this queue) needed to drive it with a fake.
    _connectivity = ref.read(connectivityRepositoryProvider);
    _reconnectedController = StreamController<void>.broadcast();
    _wasOffline = await _connectivity.isOffline();
    _connectivitySubscription = _connectivity.offlineChanges.listen(
      _onConnectivityChanged,
    );

    ref.onDispose(() {
      unawaited(_connectivitySubscription?.cancel());
      unawaited(_reconnectedController?.close());
    });

    return _keyStore.pendingMutationIds();
  }

  /// Broadcasts an event each time the device transitions from offline to
  /// online. Feature-layer code with a pending mutation (see the class doc
  /// comment) listens here to know when it's worth re-calling [run] with
  /// the same `mutationId`.
  Stream<void> get reconnected =>
      (_reconnectedController ??= StreamController<void>.broadcast()).stream;

  /// Runs one attempt of an idempotency-keyed callable.
  ///
  /// [mutationId] identifies this specific instance of a logical action
  /// (e.g. a Create-Table draft's own local id) — stable across retries of
  /// that *same* action, distinct per new action, per docs/API_SPEC.md §2.
  /// [call] receives the persisted idempotency key and should pass it as
  /// the callable's `idempotencyKey` request field untouched.
  ///
  /// If the device is offline, [call] is never invoked — this throws
  /// [OfflineMutationQueuedException] immediately instead of waiting on a
  /// call already known to fail.
  ///
  /// On success, the persisted key is released (this logical action is
  /// done) and the result is returned. On *any* failure — connectivity, a
  /// dropped response, or a rejected business rule (e.g. `TABLE_FULL`) —
  /// the persisted key is deliberately left in place and the error
  /// propagates unchanged: docs/DATABASE.md §3.9's `idempotencyKeys/{key}`
  /// record only short-circuits re-execution once `status == "completed"`
  /// (i.e. a prior run actually succeeded), so re-attempting any failed
  /// call with the same key is always safe and is exactly what makes a
  /// retry indistinguishable from the original attempt.
  Future<T> run<T>({
    required String mutationId,
    required Future<T> Function(String idempotencyKey) call,
  }) async {
    final key = await _keyStore.keyFor(mutationId);
    await _setPending(mutationId, pending: true);

    if (await _connectivity.isOffline()) {
      throw OfflineMutationQueuedException(
        mutationId: mutationId,
        idempotencyKey: key,
      );
    }

    final result = await call(key);
    await _keyStore.release(mutationId);
    await _setPending(mutationId, pending: false);
    return result;
  }

  /// Explicitly abandons a pending mutation (e.g. the user discarded a
  /// Create-Table draft rather than retrying it) — clears the persisted
  /// key so it isn't retried indefinitely. Never call this after a merely
  /// *failed* attempt the user might still retry; see [run]'s doc comment.
  Future<void> release(String mutationId) async {
    await _keyStore.release(mutationId);
    await _setPending(mutationId, pending: false);
  }

  Future<void> _setPending(String mutationId, {required bool pending}) async {
    final current = await future;
    final next = Set<String>.of(current);
    if (pending) {
      next.add(mutationId);
    } else {
      next.remove(mutationId);
    }
    state = AsyncData(next);
  }

  void _onConnectivityChanged(bool isOffline) {
    if (_wasOffline && !isOffline) {
      _reconnectedController?.add(null);
    }
    _wasOffline = isOffline;
  }
}
