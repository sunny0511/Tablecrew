import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'phone_auth_repository.g.dart';

/// Thrown by [PhoneAuthRepository] when Firebase Auth's phone-verification
/// flow rejects a send or confirm attempt (e.g. `invalid-phone-number`,
/// `invalid-verification-code`, `too-many-requests`, `session-expired`).
/// Mirrors `OnboardingCallableException`'s shape
/// (`app/lib/data/user_profile_repository.dart`) so Screens 2-3 can handle
/// both kinds of onboarding errors the same way, even though this one wraps
/// a raw [FirebaseAuthException] rather than a callable's `HttpsError`
/// details.
class PhoneAuthException implements Exception {
  /// Creates an exception carrying Firebase's own [code] and a
  /// human-readable [message].
  const PhoneAuthException({required this.code, required this.message});

  /// Firebase Auth's error code (e.g. `'invalid-verification-code'`).
  final String code;

  /// A human-readable message.
  final String message;

  @override
  String toString() => 'PhoneAuthException($code): $message';
}

/// What [PhoneAuthRepository.confirmCode] needs to confirm a code against
/// the specific SMS send that produced it.
class PhoneVerificationSession {
  /// Creates a session carrying the [verificationId] Firebase issued for
  /// this send, and — Android only — the [resendToken] a subsequent resend
  /// should pass back in.
  const PhoneVerificationSession({
    required this.verificationId,
    this.resendToken,
  });

  /// Firebase's opaque id for this specific SMS send.
  final String verificationId;

  /// Android-only: passed into a resend's `forceResendingToken` so Firebase
  /// issues a genuinely new SMS rather than silently reusing the still-valid
  /// original one. Always `null` on iOS.
  final int? resendToken;
}

/// The result of [PhoneAuthRepository.sendCode]/`resendCode` — Firebase's
/// phone flow can either send an SMS the user must type ([PhoneAuthCodeSent]),
/// or, Android only, auto-verify silently before any code is typed
/// ([PhoneAutoVerified], via the SMS Retriever API).
sealed class PhoneSendResult {
  const PhoneSendResult();
}

/// An SMS was sent — [session] is what [PhoneAuthRepository.confirmCode]
/// needs.
class PhoneAuthCodeSent extends PhoneSendResult {
  /// Creates a code-sent result carrying the [session] to confirm against.
  const PhoneAuthCodeSent(this.session);

  /// The session to pass to [PhoneAuthRepository.confirmCode].
  final PhoneVerificationSession session;
}

/// Android's SMS Retriever matched and verified the code automatically —
/// sign-in is already complete via [credential].
class PhoneAutoVerified extends PhoneSendResult {
  /// Creates an auto-verified result carrying the completed [credential].
  const PhoneAutoVerified(this.credential);

  /// The credential Firebase Auth already signed in with.
  final UserCredential credential;
}

/// Firebase Auth's phone-credential sign-in flow
/// (docs/SCREEN_SPECIFICATIONS.md Screens 2-3), wrapped from
/// `verifyPhoneNumber`'s callback-based API into a plain awaitable surface
/// so the two screens don't each reimplement the Completer/callback
/// plumbing. Lives in `features/onboarding/data/`, not `app/lib/data/`,
/// since — unlike `UserProfileRepository`/`PhotoUploadRepository` — nothing
/// outside the onboarding flow needs raw phone-verification mechanics
/// (docs/ENGINEERING_GUIDELINES.md's `app/lib/data/` is for
/// cross-feature-reusable repositories specifically).
///
/// Deliberately does not silently short-circuit Android's "instant"
/// auto-verification path into a code-free sign-in the caller can't see
/// coming — it's surfaced as [PhoneAutoVerified] instead, so Screen 2/3
/// still get to run their own post-verification routing
/// (`hasCompletedProfile` → Home vs. DOB) exactly once, from one place.
///
/// **An `abstract interface class`, not a concrete class, as of Milestone
/// F5 task #96.** The original single-class design (constructor-injectable
/// `FirebaseAuth`, per the doc comment `UserProfileRepository` also
/// carries: "the constructor parameters exist so tests can inject fakes
/// instead") turned out not to be enough on its own: `FirebaseAuth.instance`
/// is evaluated in the constructor's initializer list
/// (`_auth = auth ?? FirebaseAuth.instance`), so even a subclass overriding
/// every method still pays the cost of that lookup at construction time,
/// which throws `[core/no-app]` under a plain `flutter test` with no
/// `Firebase.initializeApp()` call. Splitting the public contract
/// ([PhoneAuthRepository], this interface) from the real implementation
/// ([FirebasePhoneAuthRepository], below) lets a hand-written test fake
/// `implements` the interface directly, touching no Firebase type — real or
/// faked — at all.
abstract interface class PhoneAuthRepository {
  /// Starts phone verification for [phoneNumber] (E.164 format, e.g.
  /// `+919876543210` — `intl_phone_field` returns numbers already in this
  /// shape). Screen 2's "Send Code".
  Future<PhoneSendResult> sendCode(String phoneNumber);

  /// Requests a fresh SMS for an already-in-flight verification — Screen 3's
  /// "Resend code" link. Passes [resendToken] through (from the prior
  /// [PhoneVerificationSession]) so Android issues a genuinely new code.
  Future<PhoneSendResult> resendCode({
    required String phoneNumber,
    int? resendToken,
  });

  /// Confirms [smsCode] against a [session] returned by [sendCode]/
  /// [resendCode], completing sign-in.
  Future<UserCredential> confirmCode({
    required PhoneVerificationSession session,
    required String smsCode,
  });

  /// Signs the current user out, without deleting the underlying Firebase
  /// Auth account — Screen 4's hard-stop under-18 screen's non-destructive
  /// option, since no `users/{uid}` profile document was ever created
  /// (the age gate runs before `completeAccountSetup`), leaving nothing
  /// else to clean up.
  Future<void> signOut();

  /// Deletes the current Firebase Auth user outright — Screen 4's
  /// hard-stop under-18 screen's destructive option, for a user who wants
  /// to fully leave rather than keep a phone-verified session around for
  /// a later attempt. A no-op if already signed out.
  Future<void> deleteAccount();
}

/// The real, Firebase-backed [PhoneAuthRepository] — see that interface's
/// doc comment for why the split exists.
///
/// Added Milestone F5.
class FirebasePhoneAuthRepository implements PhoneAuthRepository {
  /// Creates a repository over the given [auth] instance, defaulting to the
  /// app's real Firebase Auth instance.
  FirebasePhoneAuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<PhoneSendResult> sendCode(String phoneNumber) {
    return _verify(phoneNumber: phoneNumber);
  }

  @override
  Future<PhoneSendResult> resendCode({
    required String phoneNumber,
    int? resendToken,
  }) {
    return _verify(phoneNumber: phoneNumber, resendToken: resendToken);
  }

  @override
  Future<UserCredential> confirmCode({
    required PhoneVerificationSession session,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: session.verificationId,
      smsCode: smsCode,
    );
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<PhoneSendResult> _verify({
    required String phoneNumber,
    int? resendToken,
  }) {
    final completer = Completer<PhoneSendResult>();
    unawaited(
      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          if (completer.isCompleted) return;
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            completer.complete(PhoneAutoVerified(userCredential));
          } on FirebaseAuthException catch (e) {
            completer.completeError(_mapException(e));
          }
        },
        verificationFailed: (e) {
          if (completer.isCompleted) return;
          completer.completeError(_mapException(e));
        },
        codeSent: (verificationId, forceResendingToken) {
          if (completer.isCompleted) return;
          completer.complete(
            PhoneAuthCodeSent(
              PhoneVerificationSession(
                verificationId: verificationId,
                resendToken: forceResendingToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {
          // Deliberately a no-op: codeSent has already fired by this point
          // (autoRetrievalTimeout only means Android's SMS Retriever gave up
          // auto-filling, not that sending failed) — the user can still
          // type the code manually.
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  PhoneAuthException _mapException(FirebaseAuthException e) {
    return PhoneAuthException(code: e.code, message: e.message ?? e.code);
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
PhoneAuthRepository phoneAuthRepository(Ref ref) =>
    FirebasePhoneAuthRepository();
