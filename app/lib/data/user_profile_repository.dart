import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_profile_repository.g.dart';

/// Thrown by [UserProfileRepository]'s callable-backed methods when a Cloud
/// Functions callable rejects with a known, app-specific error code — the
/// `{code, message}` object docs/API_SPEC.md's callables attach as
/// `HttpsError`'s `details` third argument (e.g. `UNDER_MINIMUM_AGE`,
/// `PHOTO_NOT_APPROVED`). Callers switch on [code] rather than re-parsing
/// the raw [FirebaseFunctionsException] themselves.
class OnboardingCallableException implements Exception {
  /// Creates an exception carrying the app-specific [code] and
  /// human-readable [message] a callable's `HttpsError` details attached.
  const OnboardingCallableException({
    required this.code,
    required this.message,
  });

  /// The app-specific code (e.g. `UNDER_MINIMUM_AGE`, `PHOTO_NOT_APPROVED`)
  /// — distinct from [FirebaseFunctionsException.code], which is the
  /// generic Firebase error-code enum (`'failed-precondition'`,
  /// `'invalid-argument'`, etc.) rather than this app's own codes.
  final String code;

  /// A human-readable message, safe to show directly to the user for the
  /// codes docs/API_SPEC.md documents as having user-facing copy.
  final String message;

  @override
  String toString() => 'OnboardingCallableException($code): $message';
}

/// The result of a successful `completeAccountSetup` call
/// (docs/API_SPEC.md §3.9).
class CompleteAccountSetupResult {
  /// Creates a result carrying the newly-created account's [uid] and
  /// [verificationTierPublic].
  const CompleteAccountSetupResult({
    required this.uid,
    required this.verificationTierPublic,
  });

  /// The newly-created account's Firebase Auth UID.
  final String uid;

  /// The account's verification tier, as shown on its public profile.
  final String verificationTierPublic;
}

/// The moderation verdict for a single photo upload attempt
/// (`users/{uid}/photoModeration/{uploadId}`, docs/DATABASE.md
/// §3.1a). A sealed class rather than a bare enum since the `approved`
/// case carries the resulting download URL.
sealed class PhotoModerationStatus {
  const PhotoModerationStatus();
}

/// The moderation Function hasn't written a verdict yet — either the
/// upload is still in flight or the Vision call hasn't completed.
class PhotoModerationPending extends PhotoModerationStatus {
  /// Creates the pending-verdict state.
  const PhotoModerationPending();
}

/// A clean verdict — [approvedUrl] is the public, directly-usable download
/// URL to pass as `completeAccountSetup`'s `photoUploadId` lookup target.
class PhotoModerationApproved extends PhotoModerationStatus {
  /// Creates an approved-verdict state carrying the [approvedUrl].
  const PhotoModerationApproved(this.approvedUrl);

  /// The download URL for the approved photo.
  final String approvedUrl;
}

/// A flagged verdict — docs/SCREEN_SPECIFICATIONS.md Screen 5 routes this
/// back to the photo picker with a non-alarming rejection message, never
/// exposing the specific SafeSearch category to the user.
class PhotoModerationFlagged extends PhotoModerationStatus {
  /// Creates the flagged-verdict state.
  const PhotoModerationFlagged();
}

/// Firestore/Functions access for the `users/{uid}` public profile and
/// `users/{uid}/private/profile` documents (docs/DATABASE.md §3.1,
/// docs/API_SPEC.md §3.9). Lives in `data/`, not a feature folder, per
/// docs/ENGINEERING_GUIDELINES.md's repository structure — Screen 1
/// (Splash)'s routing and onboarding both need it, and Settings/Profile
/// (later milestones) will too.
///
/// **An `abstract interface class`, not a concrete class, as of Milestone
/// F5 task #96** — the same treatment
/// `features/onboarding/data/phone_auth_repository.dart`'s
/// `PhoneAuthRepository` got, and for the identical reason: `firestore ??
/// FirebaseFirestore.instance` / `functions ?? FirebaseFunctions.instance`
/// are evaluated in the constructor's initializer list, so even a subclass
/// overriding every method still pays for that real-Firebase lookup at
/// construction time, which throws under a plain `flutter test` with no
/// `Firebase.initializeApp()` call. Splitting the public contract (this
/// interface) from the real implementation
/// ([FirebaseUserProfileRepository], below) lets a hand-written test fake
/// `implements` the interface directly, touching no Firebase type at all.
abstract interface class UserProfileRepository {
  /// Whether `users/{uid}` (the public profile document) already exists —
  /// the exact "has this account completed onboarding" check Screen 1
  /// (Splash)'s routing logic needs (docs/SCREEN_SPECIFICATIONS.md Screen 1:
  /// "authenticated but mid-onboarding → resume at the correct step;
  /// authenticated and complete → Home"). `completeAccountSetup` is the
  /// only path that ever creates this document (docs/API_SPEC.md §3.9), so
  /// its existence is a reliable completeness signal, not a heuristic.
  Future<bool> hasCompletedProfile(String uid);

  /// docs/API_SPEC.md §3.9 — Screen 4 (Date of Birth Entry)'s "Continue"
  /// round trip. A UX convenience only; the real enforcement happens
  /// server-side again inside [completeAccountSetup], never trusted from
  /// this call alone (docs/SECURITY.md's age-gating section).
  Future<bool> validateAge(DateTime dateOfBirth);

  /// docs/API_SPEC.md §3.9 — the combined write backing Screens 5 and 6
  /// (Profile Setup, Interest Selection). [photoUploadId], if given, must
  /// reference an already-`"approved"`
  /// `users/{uid}/photoModeration/{uploadId}` document
  /// (docs/DATABASE.md §3.1a) — the server re-derives the actual photo URL
  /// itself and throws `PHOTO_NOT_APPROVED` otherwise. This method never
  /// takes or sends a raw photo URL string, matching that corrected
  /// contract (see CHANGELOG.md's "F5 kickoff" entry).
  Future<CompleteAccountSetupResult> completeAccountSetup({
    required DateTime dateOfBirth,
    required String displayName,
    required List<String> interestTags,
    required String locale,
    String? photoUploadId,
    String? bio,
  });

  /// Listens to a photo upload's moderation verdict
  /// (`users/{uid}/photoModeration/{uploadId}`, docs/DATABASE.md
  /// §3.1a) — Screen 5's "Continue" button watches this to know when a
  /// clean verdict lands, per its corrected Loading States
  /// (docs/SCREEN_SPECIFICATIONS.md Screen 5). Firestore rules restrict
  /// this document to owner-only reads (docs/DATABASE.md §6), so this only
  /// ever resolves for the signed-in user's own uploads.
  Stream<PhotoModerationStatus> watchPhotoModerationStatus({
    required String uid,
    required String uploadId,
  });
}

/// The real, Firebase-backed [UserProfileRepository] — see that interface's
/// doc comment for why the split exists.
///
/// Added Milestone F5.
class FirebaseUserProfileRepository implements UserProfileRepository {
  /// Creates a repository over the given [firestore]/[functions] instances,
  /// defaulting to the app's real Firebase instances.
  FirebaseUserProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<bool> hasCompletedProfile(String uid) async {
    final doc = await _firestore.doc('users/$uid').get();
    return doc.exists;
  }

  @override
  Future<bool> validateAge(DateTime dateOfBirth) async {
    final callable = _functions.httpsCallable('validateAge');
    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{'dateOfBirth': _formatIsoDate(dateOfBirth)},
    );
    return result.data['eligible'] as bool;
  }

  @override
  Future<CompleteAccountSetupResult> completeAccountSetup({
    required DateTime dateOfBirth,
    required String displayName,
    required List<String> interestTags,
    required String locale,
    String? photoUploadId,
    String? bio,
  }) async {
    final callable = _functions.httpsCallable('completeAccountSetup');
    try {
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'dateOfBirth': _formatIsoDate(dateOfBirth),
          'displayName': displayName,
          'interestTags': interestTags,
          'locale': locale,
          if (photoUploadId != null) 'photoUploadId': photoUploadId,
          if (bio != null) 'bio': bio,
        },
      );
      final data = result.data;
      return CompleteAccountSetupResult(
        uid: data['uid'] as String,
        verificationTierPublic: data['verificationTierPublic'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapCallableException(e);
    }
  }

  @override
  Stream<PhotoModerationStatus> watchPhotoModerationStatus({
    required String uid,
    required String uploadId,
  }) {
    // Task #97 correction: was 'users/$uid/private/photoModeration/
    // $uploadId' — 5 path segments, which Firestore's .doc() rejects at
    // runtime (document paths must have an even segment count). Never
    // caught by any Flutter test since every test drives the hand-written
    // fake, not this real implementation; found while writing the path's
    // rules-emulator tests. See functions/src/media/index.ts's matching
    // correction comment.
    return _firestore
        .doc('users/$uid/photoModeration/$uploadId')
        .snapshots()
        .map(_toModerationStatus);
  }

  PhotoModerationStatus _toModerationStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return const PhotoModerationPending();
    final data = doc.data();
    final status = data?['status'] as String? ?? 'pending';
    switch (status) {
      case 'approved':
        final approvedUrl = data?['approvedUrl'] as String?;
        return approvedUrl == null
            ? const PhotoModerationPending()
            : PhotoModerationApproved(approvedUrl);
      case 'flagged':
        return const PhotoModerationFlagged();
      default:
        return const PhotoModerationPending();
    }
  }

  OnboardingCallableException _mapCallableException(
    FirebaseFunctionsException e,
  ) {
    final details = e.details;
    if (details is Map && details['code'] is String) {
      return OnboardingCallableException(
        code: details['code'] as String,
        message: (details['message'] as String?) ?? e.message ?? e.code,
      );
    }
    return OnboardingCallableException(
      code: e.code,
      message: e.message ?? e.code,
    );
  }

  String _formatIsoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
UserProfileRepository userProfileRepository(Ref ref) =>
    FirebaseUserProfileRepository();
