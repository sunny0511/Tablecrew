import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'identity_verification_repository.g.dart';

/// Thrown by [IdentityVerificationRepository] when a Tier 2 callable
/// rejects with a known error — same shape `TrustCallableException` and
/// `TableCallableException` established: a `details.code` when the server
/// attached one (`ALREADY_VERIFIED`, `REVIEW_ALREADY_PENDING`,
/// `UPLOAD_NOT_FOUND`, `RATE_LIMITED`), otherwise the raw Firebase
/// Functions error code.
class IdentityCallableException implements Exception {
  /// Creates an exception carrying the app-specific [code] and
  /// human-readable [message].
  const IdentityCallableException({required this.code, required this.message});

  /// The app-specific code, or the generic Firebase error code when no
  /// details were attached.
  final String code;

  /// A human-readable message.
  final String message;

  @override
  String toString() => 'IdentityCallableException($code): $message';
}

/// `documentType` values `functions/src/identity/validation.ts`'s
/// `KNOWN_DOCUMENT_TYPES` accepts. This list matches that one exactly.
///
/// Self-declared and, per docs/DATABASE.md §3.10, **never treated as
/// evidence of anything** — the reviewer confirms the real document type
/// by looking at the image. It exists to make the reviewer's queue
/// readable, not to assert what was submitted.
enum IdentityDocumentType {
  /// Aadhaar, submitted as the offline/XML-verifiable document.
  aadhaar('aadhaar_offline', 'Aadhaar'),

  /// Passport.
  passport('passport', 'Passport'),

  /// Driving licence.
  driversLicense('drivers_license', 'Driving licence'),

  /// Voter ID.
  voterId('voter_id', 'Voter ID'),

  /// Anything else — the reviewer reads the actual document.
  other('other', 'Something else');

  const IdentityDocumentType(this.wireValue, this.label);

  /// The exact string `submitIdentityVerification` expects.
  final String wireValue;

  /// The user-facing label.
  final String label;
}

/// The reviewer's verdict on a submission
/// (`identityVerifications/{submissionId}.status`, docs/DATABASE.md
/// §3.10). A sealed class rather than a bare enum since the rejected case
/// carries the reason the user needs in order to act on it — the same
/// shape `PhotoModerationStatus` uses for the photo-moderation verdict.
sealed class IdentityVerificationStatus {
  const IdentityVerificationStatus();
}

/// Submitted, awaiting a human. Unlike the photo-moderation pending state
/// this is a resting state measured in hours, not seconds — Screen 8 is
/// designed to be left and returned to while in it.
class IdentityPendingReview extends IdentityVerificationStatus {
  /// Creates the awaiting-review state.
  const IdentityPendingReview();
}

/// Approved — the account is now `id_verified` and Discover-eligible.
class IdentityApproved extends IdentityVerificationStatus {
  /// Creates the approved state.
  const IdentityApproved();
}

/// Rejected, carrying the reviewer's [reason].
///
/// The reason is surfaced verbatim to the user because under manual review
/// the most common rejection cause is a fixable one (an unreadable photo),
/// so a reasonless rejection would strand someone who could simply retake
/// it. `reviewIdentityVerification` refuses a rejection with no reason for
/// exactly this purpose (docs/API_SPEC.md §3.7's
/// `REJECTION_REASON_REQUIRED`).
class IdentityRejected extends IdentityVerificationStatus {
  /// Creates a rejected state carrying the reviewer's [reason].
  const IdentityRejected(this.reason);

  /// The reviewer's stated reason.
  final String reason;
}

/// An open report existed against the account when the decision was about
/// to apply, so the grant was held for Trust & Safety
/// (docs/SECURITY.md's report-filed-mid-verification ordering rule).
///
/// Screen 8's copy for this state must never say or imply "you have been
/// reported" — that would leak the existence and timing of a report to its
/// subject. It says a person is taking a closer look.
class IdentityHeldForReview extends IdentityVerificationStatus {
  /// Creates the held-for-review state.
  const IdentityHeldForReview();
}

/// Firestore + Cloud Functions access for manual Tier 2 identity
/// verification (docs/API_SPEC.md §3.7, docs/DATABASE.md §3.10, ADR 0007).
///
/// Added Milestone F7.
abstract interface class IdentityVerificationRepository {
  /// Records a submission for human review and returns its `submissionId`.
  ///
  /// The two upload ids must already have been uploaded via
  /// `IdentityUploadRepository` — the server verifies both objects exist
  /// under the caller's own prefix and rejects with `UPLOAD_NOT_FOUND`
  /// otherwise.
  Future<String> submitIdentityVerification({
    required String idDocumentUploadId,
    required String selfieUploadId,
    required IdentityDocumentType documentType,
  });

  /// Returns the id of the open submission this user is waiting on, or
  /// `null` if there isn't one
  /// (`users/{uid}/private/profile.verification.pendingSubmissionId`,
  /// docs/DATABASE.md §3.1).
  ///
  /// This is how Screen 8 recovers after an app restart.
  /// [submitIdentityVerification] hands back the id exactly once, and
  /// `firestore.rules` denies `list` on `identityVerifications`, so
  /// without this pointer a client that lost the id could neither watch
  /// its pending review nor start a new one — `REVIEW_ALREADY_PENDING`
  /// would block it until a human intervened.
  Future<String?> fetchPendingSubmissionId(String uid);

  /// Streams the reviewer's verdict for [submissionId].
  ///
  /// `firestore.rules` grants a single-document `get` on this path to the
  /// submitting user and no `list` at all, so this is the only read shape
  /// available to the client — deliberately, since the collection indexes
  /// who submitted government ID and when.
  Stream<IdentityVerificationStatus> watchSubmission(String submissionId);
}

/// Real Firebase implementation of [IdentityVerificationRepository].
class FirebaseIdentityVerificationRepository
    implements IdentityVerificationRepository {
  /// Creates a repository over [functions] and [firestore], both
  /// defaulting to the app's real instances.
  FirebaseIdentityVerificationRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<String> submitIdentityVerification({
    required String idDocumentUploadId,
    required String selfieUploadId,
    required IdentityDocumentType documentType,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('submitIdentityVerification')
          .call<Map<String, dynamic>>(<String, dynamic>{
        'idDocumentUploadId': idDocumentUploadId,
        'selfieUploadId': selfieUploadId,
        'documentType': documentType.wireValue,
      });
      return result.data['submissionId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<String?> fetchPendingSubmissionId(String uid) async {
    // Reads the same private-profile document `UserProfileRepository`
    // already reads. Kept on this repository rather than added there so
    // the whole Milestone F7 surface stays in one place and the
    // well-covered onboarding repository is left alone.
    final doc = await _firestore.doc('users/$uid/private/profile').get();
    final verification = doc.data()?['verification'] as Map<String, dynamic>?;
    return verification?['pendingSubmissionId'] as String?;
  }

  @override
  Stream<IdentityVerificationStatus> watchSubmission(String submissionId) {
    return _firestore
        .doc('identityVerifications/$submissionId')
        .snapshots()
        .map(_toStatus);
  }

  IdentityVerificationStatus _toStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return const IdentityPendingReview();
    final data = doc.data();
    switch (data?['status'] as String?) {
      case 'approved':
        return const IdentityApproved();
      case 'rejected':
        final reason = data?['decisionReason'] as String?;
        // The server guarantees a reason on every rejection, but a client
        // that hard-depends on that would render a blank card if the
        // guarantee ever slipped. Absorbing it the way TableSummary
        // absorbs unknown enum values keeps the screen actionable.
        return IdentityRejected(
          reason?.trim().isNotEmpty ?? false
              ? reason!.trim()
              : 'We could not verify your documents this time.',
        );
      case 'held_for_review':
        return const IdentityHeldForReview();
      case 'pending_review':
      default:
        // Unknown-absorbing: an unrecognized status means a server that
        // has moved ahead of this client, and "still waiting" is the only
        // safe thing to show — never a granted-looking state.
        return const IdentityPendingReview();
    }
  }

  IdentityCallableException _mapException(FirebaseFunctionsException e) {
    final details = e.details;
    if (details is Map && details['code'] is String) {
      return IdentityCallableException(
        code: details['code'] as String,
        message: (details['message'] as String?) ?? e.message ?? e.code,
      );
    }
    return IdentityCallableException(
      code: e.code,
      message: e.message ?? e.code,
    );
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
IdentityVerificationRepository identityVerificationRepository(Ref ref) =>
    FirebaseIdentityVerificationRepository();
