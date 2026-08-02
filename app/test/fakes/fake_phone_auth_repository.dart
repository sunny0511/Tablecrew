import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';

/// A [Mock]-based stand-in for [UserCredential] — see `pubspec.yaml`'s
/// `mocktail` dev-dependency comment for why a real constructor isn't an
/// option here (pub.dev's own API docs confirm [UserCredential] has none).
class MockUserCredential extends Mock implements UserCredential {}

/// A [Mock]-based stand-in for [User], sufficient for the one property
/// (`uid`) anything downstream of [PhoneAuthRepository.confirmCode]
/// currently reads (`OtpScreen._confirm`'s `state.credential?.user?.uid`).
class MockUser extends Mock implements User {}

/// Builds a [MockUserCredential] whose `user.uid` is [uid] — the one shape
/// every real call site needs, without hand-threading Mocktail's `when()`
/// stubbing into every test that just needs "a credential for this uid."
MockUserCredential fakeUserCredential(String uid) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  final credential = MockUserCredential();
  when(() => credential.user).thenReturn(user);
  return credential;
}

/// Hand-written fake of [PhoneAuthRepository]
/// (`features/onboarding/data/phone_auth_repository.dart`) — `implements`
/// the interface directly, touching no real Firebase Auth SDK type except
/// the two Mocktail-based leaf stand-ins above. Used by
/// `OnboardingPhoneFlowController`'s tests (Milestone F5 task #96).
///
/// [sendCodeResults]/[confirmCodeResults] are FIFO queues rather than a
/// single "next result" field, since `resendCode` reuses `sendCode`'s
/// result queue (matching `OnboardingPhoneFlowController._send`'s own
/// shared code path) and a lockout test needs several `confirmCode` calls
/// in a row, each returning its own [PhoneAuthException].
class FakePhoneAuthRepository implements PhoneAuthRepository {
  /// Queue of values to return from successive [sendCode]/[resendCode]
  /// calls, consumed FIFO. Populate with [PhoneSendResult] instances for a
  /// success or [PhoneAuthException] instances for a failure — anything
  /// else throws [ArgumentError] on consumption, since that would be a
  /// test-authoring mistake, not a device-under-test failure.
  final List<Object> sendCodeResults = [];

  /// Queue of values to return from successive [confirmCode] calls,
  /// consumed FIFO — same shape as [sendCodeResults] but with
  /// [UserCredential] (e.g. [fakeUserCredential]) as the success payload.
  final List<Object> confirmCodeResults = [];

  /// Every phone number [sendCode] was called with, in order.
  final List<String> sendCodeCalls = [];

  /// Every `(phoneNumber, resendToken)` pair [resendCode] was called with,
  /// in order.
  final List<({String phoneNumber, int? resendToken})> resendCodeCalls = [];

  /// Every `(session, smsCode)` pair [confirmCode] was called with, in
  /// order.
  final List<({PhoneVerificationSession session, String smsCode})>
      confirmCodeCalls = [];

  /// How many times [signOut] was called.
  int signOutCallCount = 0;

  /// How many times [deleteAccount] was called.
  int deleteAccountCallCount = 0;

  @override
  Future<PhoneSendResult> sendCode(String phoneNumber) async {
    sendCodeCalls.add(phoneNumber);
    return _consume<PhoneSendResult>(sendCodeResults);
  }

  @override
  Future<PhoneSendResult> resendCode({
    required String phoneNumber,
    int? resendToken,
  }) async {
    resendCodeCalls.add((phoneNumber: phoneNumber, resendToken: resendToken));
    return _consume<PhoneSendResult>(sendCodeResults);
  }

  @override
  Future<UserCredential> confirmCode({
    required PhoneVerificationSession session,
    required String smsCode,
  }) async {
    confirmCodeCalls.add((session: session, smsCode: smsCode));
    return _consume<UserCredential>(confirmCodeResults);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
  }

  T _consume<T>(List<Object> queue) {
    if (queue.isEmpty) {
      throw StateError(
        'FakePhoneAuthRepository: no queued result for a call expecting '
        '$T — populate sendCodeResults/confirmCodeResults before calling.',
      );
    }
    final next = queue.removeAt(0);
    if (next is Exception) throw next;
    if (next is! T) {
      throw ArgumentError(
        'FakePhoneAuthRepository: queued a ${next.runtimeType} where a $T '
        'or Exception was expected — check the test setup.',
      );
    }
    return next as T;
  }
}
