import 'dart:async';
import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';

part 'account_setup_controller.g.dart';

/// [AccountSetupController]'s lifecycle states.
enum AccountSetupStatus {
  /// Nothing submitted yet.
  idle,

  /// A `completeAccountSetup` call is in flight.
  submitting,

  /// Offline at submit time — deferred, waiting for connectivity to retry
  /// automatically. Screen 6's Offline Behavior: "selections queue and
  /// sync on reconnect, and onboarding proceeds optimistically."
  queued,

  /// `completeAccountSetup` succeeded (this attempt or a queued retry).
  succeeded,

  /// A real, non-connectivity error — see [AccountSetupState.errorCode].
  failed,
}

/// [AccountSetupController]'s state.
class AccountSetupState {
  /// Creates a state, defaulting to [AccountSetupStatus.idle].
  const AccountSetupState({
    this.status = AccountSetupStatus.idle,
    this.errorCode,
    this.errorMessage,
  });

  /// The current status.
  final AccountSetupStatus status;

  /// Set only when [status] is [AccountSetupStatus.failed] and the
  /// failure was a known `OnboardingCallableException` code (e.g.
  /// `UNDER_MINIMUM_AGE`, `PHOTO_NOT_APPROVED`) — `null` for an
  /// unrecognized/generic failure.
  final String? errorCode;

  /// A human-readable message for [status] == [AccountSetupStatus.failed].
  final String? errorMessage;
}

/// Drives Screen 6 (Interest Selection)'s "Continue" — the single
/// `completeAccountSetup` call that actually creates the account, per
/// `docs/SCREEN_SPECIFICATIONS.md` Screen 6's API Calls note ("the client
/// stages this screen's selections locally and fires the one combined
/// call once Profile Setup's fields are also ready").
///
/// **Not built on `core/offline/OfflineMutationQueue`.** That queue's
/// `run()` requires the wrapped call to accept a persisted idempotency
/// key (`docs/API_SPEC.md` §2's pattern for `[idempotent]`-tagged
/// callables like `createTable`/`requestSeat`). `completeAccountSetup` is
/// deliberately **not** tagged `[idempotent]` and its request schema has
/// no `idempotencyKey` field at all (`docs/API_SPEC.md` §3.9) — instead
/// `functions/src/users/index.ts`'s own implementation comment states
/// it's "idempotent-by-construction": a retry that finds `users/{uid}`
/// already created just returns the existing data rather than erroring,
/// since a caller can only ever create their own uid's documents. That
/// makes a plain "retry the same call again once online" safe without
/// needing the queue's key machinery at all.
///
/// `keepAlive: true` (unlike most feature controllers, which are
/// `autoDispose` by default) — Screen 6 can navigate away immediately
/// after queuing an offline submission (per the Offline Behavior note
/// above), and the pending retry must keep running, and this state must
/// stay readable for a background sync banner, after that screen is gone.
///
/// Added Milestone F5.
@Riverpod(keepAlive: true)
class AccountSetupController extends _$AccountSetupController {
  StreamSubscription<bool>? _reconnectSubscription;

  @override
  AccountSetupState build() {
    ref.onDispose(() => unawaited(_reconnectSubscription?.cancel()));
    return const AccountSetupState();
  }

  /// Submits the current [OnboardingProfileDraft]. Returns `true` if the
  /// caller should proceed to Notification Permission Priming right away
  /// — either the call actually succeeded, or it was safely queued for a
  /// background retry (see the class doc comment). Returns `false` for a
  /// real, blocking error; inspect [state] for which one.
  Future<bool> submit() async {
    state = const AccountSetupState(status: AccountSetupStatus.submitting);

    // Milestone F5 task #96: this used to construct `Connectivity()`
    // directly, the same untestable-under-plain-`flutter test` pattern
    // task #113 already fixed in the 4 screens that needed connectivity
    // checks — this controller was missed in that pass and is reconciled
    // to the same `ConnectivityRepository` wrapper here, so it can be
    // driven by a fake in tests without touching a real platform channel.
    final connectivity = ref.read(connectivityRepositoryProvider);
    if (await connectivity.isOffline()) {
      state = const AccountSetupState(status: AccountSetupStatus.queued);
      _waitForReconnectThenRetry(connectivity);
      return true;
    }

    return _attempt();
  }

  void _waitForReconnectThenRetry(ConnectivityRepository connectivity) {
    unawaited(_reconnectSubscription?.cancel());
    _reconnectSubscription = connectivity.offlineChanges.listen((isOffline) {
      if (isOffline) return;
      unawaited(_reconnectSubscription?.cancel());
      unawaited(_attempt());
    });
  }

  Future<bool> _attempt() async {
    final draft = ref.read(onboardingProfileDraftControllerProvider);
    final dateOfBirth = draft.dateOfBirth;
    final displayName = draft.displayName;
    if (dateOfBirth == null || displayName == null) {
      // Screens 4/5 already guarantee these are staged before Screen 6 is
      // reachable — this is a defensive guard, not an expected path.
      state = const AccountSetupState(
        status: AccountSetupStatus.failed,
        errorMessage: 'Missing required profile details — start over.',
      );
      return false;
    }

    state = const AccountSetupState(status: AccountSetupStatus.submitting);
    try {
      await ref.read(userProfileRepositoryProvider).completeAccountSetup(
            dateOfBirth: dateOfBirth,
            displayName: displayName,
            interestTags: draft.interestTags,
            locale: ui.PlatformDispatcher.instance.locale.toLanguageTag(),
            photoUploadId: draft.photoUploadId,
            bio: draft.bio,
          );
      ref.read(onboardingProfileDraftControllerProvider.notifier).reset();
      state = const AccountSetupState(status: AccountSetupStatus.succeeded);
      return true;
    } on OnboardingCallableException catch (e) {
      state = AccountSetupState(
        status: AccountSetupStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
      return false;
    }
  }
}
