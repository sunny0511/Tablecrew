import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_repository.g.dart';

/// The online/offline signal the onboarding screens that need one (Phone
/// Number Entry, OTP Verification, Date of Birth Entry, Profile Setup) and
/// `AccountSetupController` all read, behind this codebase's repository
/// convention (`docs/ENGINEERING_GUIDELINES.md`: "swap in a fake
/// repository, never hit ... for a unit test"). Also collapses what used to
/// be each screen's own near-identical `_isOfflineResult` helper into one
/// shared definition of "offline": `docs/SCREEN_SPECIFICATIONS.md`'s
/// onboarding screens don't distinguish wifi vs. mobile vs. any other
/// connected state, only connected vs. not.
///
/// **An `abstract interface class`, not a concrete class, as of Milestone
/// F5 task #96** — the same treatment
/// `features/onboarding/data/phone_auth_repository.dart`'s
/// `PhoneAuthRepository` got, applied here too for consistency across every
/// repository in this codebase (rather than a hybrid of "some repositories
/// split, some not"): `connectivity_plus`'s own `checkConnectivity()`/
/// `onConnectivityChanged` throw `MissingPluginException` under a plain
/// `flutter test` with no platform channel mock wired up (confirmed while
/// fixing `app_test.dart`, Milestone F5 — see `TASKS.md`), so tests need a
/// hand-written fake that `implements` this interface directly rather than
/// one that has to contend with `connectivity_plus`'s real `Connectivity`/
/// `ConnectivityResult` types at all.
///
/// Added Milestone F5 (task #113, as a concrete class closing a
/// testability gap surfaced while verifying task #95; split into this
/// interface + [PlatformConnectivityRepository] in task #96 once the same
/// gap turned up again for `AccountSetupController`'s still-untestable raw
/// `Connectivity()` use).
abstract interface class ConnectivityRepository {
  /// A one-shot check — `true` if the device currently has no usable
  /// connectivity type at all.
  Future<bool> isOffline();

  /// Fires whenever the offline/online state changes (not on every raw
  /// connectivity event — e.g. wifi-to-mobile while still online doesn't
  /// emit, since callers only care about the offline/online boundary).
  Stream<bool> get offlineChanges;
}

/// The real, `connectivity_plus`-backed [ConnectivityRepository].
class PlatformConnectivityRepository implements ConnectivityRepository {
  /// Creates a repository over the given [connectivity] instance,
  /// defaulting to the real platform plugin.
  PlatformConnectivityRepository({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOffline() async {
    return _isOffline(await _connectivity.checkConnectivity());
  }

  @override
  Stream<bool> get offlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOffline).distinct();

  bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);
}

/// Riverpod provider (`docs/ENGINEERING_GUIDELINES.md`: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
ConnectivityRepository connectivityRepository(Ref ref) =>
    PlatformConnectivityRepository();
