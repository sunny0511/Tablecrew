import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Local, on-device persistence for the mutationId -> idempotencyKey
/// mapping docs/API_SPEC.md §2 requires: "The client SDK wrapper generates
/// and persists the key locally before the first attempt, so a retry (even
/// across an app restart) reuses it rather than minting a new one, which
/// would defeat the purpose."
///
/// `mutationId` is a caller-chosen identifier for one specific instance of
/// a logical user action (e.g. a Create-Table draft's own local id) —
/// distinct from the `idempotencyKey` itself, which is the opaque,
/// server-facing UUID v4 docs/API_SPEC.md §2 and
/// `functions/src/shared/index.ts`'s `isWellFormedIdempotencyKey` require.
/// Keeping the two separate lets feature code choose stable, meaningful
/// mutation ids while this store owns generating and persisting the actual
/// key.
///
/// Backed by a single JSON blob in `SharedPreferences` rather than one pref
/// entry per mutation: Foundation-scope usage is a handful of concurrent
/// pending mutations at most (one Create-Table draft, one Create-Crew
/// draft, a pending Rating), so the simplicity of one read/write per
/// operation outweighs the query flexibility a real embedded database
/// (Hive/sqflite) would add. Revisit if a later milestone needs to queue
/// many more pending mutations at once — Table Chat's own offline message
/// queue (`features/tables/README.md`) is deliberately NOT built on this
/// store, since chat messages aren't idempotency-keyed callables.
class IdempotencyKeyStore {
  /// Creates a store backed by the given [SharedPreferences] instance.
  /// [uuid] is injectable for testing; defaults to a real generator.
  IdempotencyKeyStore(this._prefs, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  static const _prefsKey = 'core.offlineMutationQueue.pendingKeysV1';

  final SharedPreferences _prefs;
  final Uuid _uuid;

  Map<String, String> _readAll() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> _writeAll(Map<String, String> all) {
    return _prefs.setString(_prefsKey, jsonEncode(all));
  }

  /// Returns the persisted idempotency key for [mutationId], generating and
  /// persisting a new UUID v4 first if none exists yet. Safe to call
  /// repeatedly for the same [mutationId] (e.g. across retries or an app
  /// restart) — it keeps returning the same key until [release] is called
  /// for that [mutationId].
  Future<String> keyFor(String mutationId) async {
    final all = _readAll();
    final existing = all[mutationId];
    if (existing != null) return existing;

    final generated = _uuid.v4();
    all[mutationId] = generated;
    await _writeAll(all);
    return generated;
  }

  /// Clears the persisted key for [mutationId]. Call this once the logical
  /// action has actually succeeded (the server returned a non-error
  /// response), or if the user has abandoned the action entirely (e.g.
  /// discarded a draft) — never after a merely *failed* attempt, since a
  /// failed attempt must still be retried with the *same* key per
  /// docs/API_SPEC.md §2.
  Future<void> release(String mutationId) async {
    final all = _readAll();
    if (all.remove(mutationId) == null) return;
    await _writeAll(all);
  }

  /// Every mutationId with a currently-persisted (i.e. not yet succeeded or
  /// released) idempotency key.
  Set<String> pendingMutationIds() => _readAll().keys.toSet();
}
