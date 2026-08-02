import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';

part 'onboarding_phone_flow_controller.g.dart';

/// Where [OnboardingPhoneFlowState] is in the Screen 2 -> Screen 3 flow.
enum OnboardingPhoneFlowStatus {
  /// Nothing sent yet.
  initial,

  /// A send/resend request is in flight.
  sending,

  /// An SMS was sent; waiting for the user to type/auto-fill a code.
  codeSent,

  /// Android's SMS Retriever auto-verified before any code was typed.
  autoVerified,

  /// The most recent send attempt failed.
  sendFailed,

  /// A confirm (code-check) request is in flight.
  confirming,

  /// The entered code was confirmed — sign-in is complete.
  confirmed,

  /// The entered code was wrong (and the field isn't locked yet).
  confirmFailed,

  /// Too many wrong attempts — locked out until `lockedUntil`
  /// ([OnboardingPhoneFlowState]).
  locked,
}

/// In-flight state for the Phone Number Entry -> OTP Verification pair
/// (docs/SCREEN_SPECIFICATIONS.md Screens 2-3).
///
/// A plain field-holder with a status enum, not a sealed-class-per-state
/// hierarchy (contrast `PhotoModerationStatus`,
/// `app/lib/data/user_profile_repository.dart`): unlike that Firestore
/// verdict, which only ever needs one payload field alive at a time, this
/// state has fields (`phoneNumber`, `session`) that stay meaningful across
/// almost every status — Screen 3's "Resend code" and "Edit number" both
/// need [phoneNumber] regardless of whether the last attempt succeeded or
/// failed, and a sealed hierarchy would force re-threading it through every
/// variant.
class OnboardingPhoneFlowState {
  /// Creates a flow state. Prefer [OnboardingPhoneFlowState.initial] for the
  /// starting state and [copyWith] for transitions.
  const OnboardingPhoneFlowState({
    required this.status,
    this.phoneNumber,
    this.session,
    this.credential,
    this.exception,
    this.wrongAttemptCount = 0,
    this.lockedUntil,
    this.codeSentAt,
  });

  /// The starting state before any send has happened.
  const OnboardingPhoneFlowState.initial()
      : this(status: OnboardingPhoneFlowStatus.initial);

  /// Where the flow currently is.
  final OnboardingPhoneFlowStatus status;

  /// The phone number (E.164) the flow is currently running for.
  final String? phoneNumber;

  /// The in-flight verification session, once a send has succeeded.
  final PhoneVerificationSession? session;

  /// The completed sign-in credential, once confirmed or auto-verified.
  final UserCredential? credential;

  /// The most recent send/confirm failure, if any.
  final PhoneAuthException? exception;

  /// Consecutive wrong-code attempts since the last successful send.
  final int wrongAttemptCount;

  /// When a lockout (Screen 3: "after 5 incorrect attempts, the field locks
  /// for 60 seconds") ends, or `null` if not locked.
  final DateTime? lockedUntil;

  /// When the current code was sent — Screen 3's "codes expire after 5
  /// minutes" is computed from this by the UI.
  final DateTime? codeSentAt;

  /// Returns a copy with the given fields replaced. [clearException] and
  /// [clearLockedUntil] exist because `null` as a positional value can't be
  /// distinguished from "leave unchanged" for a nullable field.
  OnboardingPhoneFlowState copyWith({
    OnboardingPhoneFlowStatus? status,
    String? phoneNumber,
    PhoneVerificationSession? session,
    UserCredential? credential,
    PhoneAuthException? exception,
    int? wrongAttemptCount,
    DateTime? lockedUntil,
    DateTime? codeSentAt,
    bool clearException = false,
    bool clearLockedUntil = false,
  }) {
    return OnboardingPhoneFlowState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      session: session ?? this.session,
      credential: credential ?? this.credential,
      exception: clearException ? null : exception ?? this.exception,
      wrongAttemptCount: wrongAttemptCount ?? this.wrongAttemptCount,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
      codeSentAt: codeSentAt ?? this.codeSentAt,
    );
  }
}

/// Drives Screens 2-3's send/resend/confirm sequence against
/// [PhoneAuthRepository], holding the state that needs to survive
/// navigation between the two routes. Deliberately a Riverpod provider
/// rather than passed through `GoRouterState.extra`: `extra` doesn't
/// survive a deep link or an app restart mid-flow, and Screen 3's own
/// "Edit number" back-navigation needs to read (then discard) it cleanly.
///
/// Added Milestone F5.
@riverpod
class OnboardingPhoneFlowController extends _$OnboardingPhoneFlowController {
  static const _maxWrongAttempts = 5;
  static const _lockDuration = Duration(seconds: 60);

  @override
  OnboardingPhoneFlowState build() => const OnboardingPhoneFlowState.initial();

  /// Screen 2's "Send Code" — starts (or restarts, e.g. after "Edit number")
  /// verification for [phoneNumber] (E.164).
  Future<void> sendCode(String phoneNumber) async {
    state = state.copyWith(
      status: OnboardingPhoneFlowStatus.sending,
      phoneNumber: phoneNumber,
      wrongAttemptCount: 0,
      clearLockedUntil: true,
      clearException: true,
    );
    await _send(phoneNumber: phoneNumber);
  }

  /// Screen 3's "Resend code" link — reuses the in-flight phone number and,
  /// on Android, the prior session's resend token.
  Future<void> resendCode() async {
    final phoneNumber = state.phoneNumber;
    if (phoneNumber == null) return;
    state = state.copyWith(
      status: OnboardingPhoneFlowStatus.sending,
      wrongAttemptCount: 0,
      clearLockedUntil: true,
      clearException: true,
    );
    await _send(
      phoneNumber: phoneNumber,
      resendToken: state.session?.resendToken,
    );
  }

  /// Screen 3's auto-submit-on-6th-digit — confirms [smsCode] against the
  /// in-flight session. A no-op while locked out.
  Future<void> confirmCode(String smsCode) async {
    final session = state.session;
    if (session == null) return;
    final lockedUntil = state.lockedUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) return;

    state = state.copyWith(status: OnboardingPhoneFlowStatus.confirming);
    final repository = ref.read(phoneAuthRepositoryProvider);
    try {
      final credential = await repository.confirmCode(
        session: session,
        smsCode: smsCode,
      );
      state = state.copyWith(
        status: OnboardingPhoneFlowStatus.confirmed,
        credential: credential,
        wrongAttemptCount: 0,
      );
    } on PhoneAuthException catch (e) {
      final attempts = state.wrongAttemptCount + 1;
      final locked = attempts >= _maxWrongAttempts;
      state = state.copyWith(
        status: locked
            ? OnboardingPhoneFlowStatus.locked
            : OnboardingPhoneFlowStatus.confirmFailed,
        exception: e,
        wrongAttemptCount: attempts,
        lockedUntil: locked ? DateTime.now().add(_lockDuration) : null,
      );
    }
  }

  /// Clears a non-locked confirm failure so a fresh [confirmCode] can run.
  /// Screen 3: "An incorrect code triggers an inline shake + error message
  /// without clearing the field" — the field's own text stays in the
  /// screen's local widget state; this only clears the controller-level
  /// error.
  void clearConfirmError() {
    if (state.status != OnboardingPhoneFlowStatus.confirmFailed) return;
    state = state.copyWith(
      status: OnboardingPhoneFlowStatus.codeSent,
      clearException: true,
    );
  }

  /// "Edit number" — discards the in-flight session entirely rather than
  /// leaving stale state a re-entered number might accidentally inherit.
  void reset() {
    state = const OnboardingPhoneFlowState.initial();
  }

  Future<void> _send({required String phoneNumber, int? resendToken}) async {
    final repository = ref.read(phoneAuthRepositoryProvider);
    try {
      final result = resendToken == null
          ? await repository.sendCode(phoneNumber)
          : await repository.resendCode(
              phoneNumber: phoneNumber,
              resendToken: resendToken,
            );
      switch (result) {
        case PhoneAuthCodeSent(:final session):
          state = state.copyWith(
            status: OnboardingPhoneFlowStatus.codeSent,
            session: session,
            codeSentAt: DateTime.now(),
          );
        case PhoneAutoVerified(:final credential):
          state = state.copyWith(
            status: OnboardingPhoneFlowStatus.autoVerified,
            credential: credential,
          );
      }
    } on PhoneAuthException catch (e) {
      state = state.copyWith(
        status: OnboardingPhoneFlowStatus.sendFailed,
        exception: e,
      );
    }
  }
}
