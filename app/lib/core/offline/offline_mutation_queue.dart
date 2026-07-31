import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/core/offline/idempotency_key_store.dart';

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
@riverpod
class OfflineMutationQueue extends _$OfflineMutationQueue {
  late IdempotencyKeyStore _keyStore;
  late Connectivity _connectivity;
  StreamController<void>? _reconnectedController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _keyStore = IdempotencyKeyStore(prefs);
    _connectivity = Connectivity();
    _reconnectedController = StreamController<void>.broadcast();
    _wasOffline = _isOffline(await _connectivity.checkConnectivity());
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
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

    if (_isOffline(await _connectivity.checkConnectivity())) {
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

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = _isOffline(results);
    if (_wasOffline && !isOffline) {
      _reconnectedController?.add(null);
    }
    _wasOffline = isOffline;
  }

  bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);
}
