import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'phone_send_rate_tracker.g.dart';

/// Tracks phone-verification send attempts per phone number to back
/// docs/SCREEN_SPECIFICATIONS.md Screen 2's rate-limit validation rule ("5
/// send attempts to the same number within 15 minutes ... the button
/// disables and a cooldown timer is shown instead of a silent failure").
///
/// Firebase Auth's phone-auth flow has no client-visible per-number
/// send-rate signal of its own — its `too-many-requests` error only
/// surfaces after Firebase's own, much coarser, project-wide abuse
/// threshold trips. This tracker is therefore a deliberately client-side,
/// best-effort UX improvement (a real cooldown timer instead of a
/// confusing late error), not a security control — the same relationship
/// every other client-side rate-limit UI in this codebase has to its
/// server-side counterpart (e.g. `functions/src/shared/rateLimit.ts`'s
/// bucket is the real enforcement boundary for Tables/Crews callables; this
/// has no equivalent server bucket to point at, since phone-auth sends
/// aren't a TableCrew callable at all).
///
/// Persisted via `shared_preferences` (not just in-memory) so the 15-minute
/// window survives an app restart mid-flow, the same reason
/// `IdempotencyKeyStore` (`core/offline/`) persists across restarts.
///
/// Added Milestone F5.
class PhoneSendRateTracker {
  /// Creates a tracker backed by the given `prefs` instance.
  PhoneSendRateTracker(this._prefs);

  final SharedPreferences _prefs;

  static const _maxAttempts = 5;
  static const _window = Duration(minutes: 15);

  /// Whether [phoneNumber] may send another code right now.
  bool canSend(String phoneNumber, {DateTime? now}) {
    return _attemptsInWindow(phoneNumber, now: now).length < _maxAttempts;
  }

  /// When the oldest attempt in the current window falls out of it — i.e.
  /// when [canSend] will next become true — or `null` if it already is.
  DateTime? cooldownUntil(String phoneNumber, {DateTime? now}) {
    final attempts = _attemptsInWindow(phoneNumber, now: now);
    if (attempts.length < _maxAttempts) return null;
    return attempts.first.add(_window);
  }

  /// Records a send attempt for [phoneNumber] at [now] (injectable for
  /// tests; defaults to the real current time).
  Future<void> recordAttempt(String phoneNumber, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final attempts = _attemptsInWindow(phoneNumber, now: effectiveNow)
      ..add(effectiveNow);
    await _prefs.setStringList(
      _key(phoneNumber),
      attempts.map((t) => t.toIso8601String()).toList(),
    );
  }

  List<DateTime> _attemptsInWindow(String phoneNumber, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(_window);
    final raw = _prefs.getStringList(_key(phoneNumber)) ?? const <String>[];
    final parsed = raw
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where(
          (t) => t.isAfter(cutoff),
        )
        .toList()
      ..sort();
    return parsed;
  }

  String _key(String phoneNumber) => 'phone_send_attempts_$phoneNumber';
}

/// Riverpod provider — async since `SharedPreferences.getInstance()` is
/// itself async, matching `OfflineMutationQueue.build()`'s identical
/// pattern (`core/offline/offline_mutation_queue.dart`).
@riverpod
Future<PhoneSendRateTracker> phoneSendRateTracker(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return PhoneSendRateTracker(prefs);
}
