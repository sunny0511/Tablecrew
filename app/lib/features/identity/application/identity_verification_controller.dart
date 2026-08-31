import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/data/identity_upload_repository.dart';
import 'package:tablecrew/data/identity_verification_repository.dart';

part 'identity_verification_controller.g.dart';

/// [IdentityVerificationController]'s lifecycle states.
enum IdentitySubmitStatus {
  /// Capturing — nothing sent yet.
  idle,

  /// Restoring an open submission after an app restart (reading
  /// `verification.pendingSubmissionId`).
  restoring,

  /// Uploading the two images to Cloud Storage.
  uploading,

  /// Images uploaded; `submitIdentityVerification` is in flight.
  submitting,

  /// Submitted — [IdentityVerificationState.submissionId] is set and the
  /// screen watches it for the reviewer's verdict.
  submitted,

  /// A real failure — see [IdentityVerificationState.errorCode].
  failed,
}

/// [IdentityVerificationController]'s state.
class IdentityVerificationState {
  /// Creates a state, defaulting to [IdentitySubmitStatus.idle].
  const IdentityVerificationState({
    this.status = IdentitySubmitStatus.idle,
    this.documentType = IdentityDocumentType.aadhaar,
    this.idDocumentBytes,
    this.idDocumentContentType,
    this.selfieBytes,
    this.selfieContentType,
    this.submissionId,
    this.errorCode,
    this.errorMessage,
  });

  /// The current status.
  final IdentitySubmitStatus status;

  /// The self-declared document type (never trusted server-side — see
  /// [IdentityDocumentType]). Defaults to Aadhaar, the most likely
  /// document in the Hyderabad anchor market (docs/ROADMAP.md Phase 0).
  final IdentityDocumentType documentType;

  /// The captured government-ID image, held only in memory.
  final Uint8List? idDocumentBytes;

  /// MIME type of [idDocumentBytes].
  final String? idDocumentContentType;

  /// The captured selfie, held only in memory.
  final Uint8List? selfieBytes;

  /// MIME type of [selfieBytes].
  final String? selfieContentType;

  /// The submission being reviewed, once submitted or restored.
  final String? submissionId;

  /// Set only when [status] is [IdentitySubmitStatus.failed] and the
  /// failure carried a known [IdentityCallableException] code (e.g.
  /// `RATE_LIMITED`, `ALREADY_VERIFIED`) — `null` for a generic failure.
  final String? errorCode;

  /// A human-readable message for [IdentitySubmitStatus.failed].
  final String? errorMessage;

  /// Whether both images are captured and nothing is in flight.
  bool get canSubmit =>
      idDocumentBytes != null &&
      selfieBytes != null &&
      (status == IdentitySubmitStatus.idle ||
          status == IdentitySubmitStatus.failed);

  /// Copies this state. Every field is unchanged unless named — clearing a
  /// value is done by the controller's own dedicated methods rather than
  /// by passing `null` here, since a `copyWith` that cannot tell "leave
  /// alone" from "set to null" is exactly the ambiguity
  /// `OnboardingPhoneFlowState`'s tests were written to pin down.
  IdentityVerificationState copyWith({
    IdentitySubmitStatus? status,
    IdentityDocumentType? documentType,
    Uint8List? idDocumentBytes,
    String? idDocumentContentType,
    Uint8List? selfieBytes,
    String? selfieContentType,
    String? submissionId,
    String? errorCode,
    String? errorMessage,
  }) {
    return IdentityVerificationState(
      status: status ?? this.status,
      documentType: documentType ?? this.documentType,
      idDocumentBytes: idDocumentBytes ?? this.idDocumentBytes,
      idDocumentContentType:
          idDocumentContentType ?? this.idDocumentContentType,
      selfieBytes: selfieBytes ?? this.selfieBytes,
      selfieContentType: selfieContentType ?? this.selfieContentType,
      submissionId: submissionId ?? this.submissionId,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Drives Screen 8 (docs/SCREEN_SPECIFICATIONS.md), manual Tier 2 identity
/// verification per ADR 0007.
///
/// `keepAlive: true` for the reason this codebase has now hit three times
/// (`SplashScreen` task #95, `OnboardingProfileDraftController` task #96,
/// `OfflineMutationQueue` F6 chunk 2): an autoDispose provider that every
/// call site only ever `ref.read`s is liable to be torn down between two
/// reads. Here the consequence would be losing a `submissionId` mid-upload
/// — with the images already in Cloud Storage and a submission possibly
/// already created, which `REVIEW_ALREADY_PENDING` would then block the
/// user from retrying.
///
/// Deliberately **not** routed through `OfflineMutationQueue`, matching
/// Screens 27-28's treatment of reports and blocks: identity verification
/// gates access to strangers, so it should be submitted deliberately by a
/// present user rather than replayed later from a background queue.
///
/// The captured images live only in this state — never on disk. An
/// unsubmitted government ID should not outlive the session that captured
/// it, which is also why there is no draft-persistence here of the kind
/// `CreateTableDraftController` uses.
///
/// Added Milestone F7.
@Riverpod(keepAlive: true)
class IdentityVerificationController extends _$IdentityVerificationController {
  @override
  IdentityVerificationState build() => const IdentityVerificationState();

  /// Looks for an open submission left behind by a previous app run and
  /// adopts it, so a user who closed the app mid-review returns to the
  /// waiting state rather than to a capture screen they cannot get past
  /// (`submitIdentityVerification` would reject them with
  /// `REVIEW_ALREADY_PENDING`).
  Future<void> restorePendingSubmission(String uid) async {
    if (state.submissionId != null) return;
    state = state.copyWith(status: IdentitySubmitStatus.restoring);
    try {
      final pending = await ref
          .read(identityVerificationRepositoryProvider)
          .fetchPendingSubmissionId(uid);
      state = pending == null
          ? const IdentityVerificationState()
          : state.copyWith(
              status: IdentitySubmitStatus.submitted,
              submissionId: pending,
            );
    } on Exception {
      // A failed lookup must not strand the user on a spinner — fall back
      // to the capture flow. The worst case is a REVIEW_ALREADY_PENDING on
      // submit, which the screen renders as a real, explained state.
      state = const IdentityVerificationState();
    }
  }

  /// Records the captured government-ID image.
  void setIdDocument(Uint8List bytes, String contentType) {
    state = state.copyWith(
      idDocumentBytes: bytes,
      idDocumentContentType: contentType,
      status: IdentitySubmitStatus.idle,
    );
  }

  /// Records the captured selfie.
  void setSelfie(Uint8List bytes, String contentType) {
    state = state.copyWith(
      selfieBytes: bytes,
      selfieContentType: contentType,
      status: IdentitySubmitStatus.idle,
    );
  }

  /// Records the self-declared document type.
  void setDocumentType(IdentityDocumentType type) {
    state = state.copyWith(documentType: type);
  }

  /// Clears everything and returns to capture — used by "Try again" after
  /// a rejection.
  void reset() {
    state = const IdentityVerificationState();
  }

  /// Uploads both images and submits them for review. Returns `true` on
  /// success.
  Future<bool> submit(String uid) async {
    final idBytes = state.idDocumentBytes;
    final selfieBytes = state.selfieBytes;
    if (idBytes == null || selfieBytes == null) return false;

    state = state.copyWith(status: IdentitySubmitStatus.uploading);
    try {
      final uploads = ref.read(identityUploadRepositoryProvider);
      final idUploadId = await uploads.uploadIdentityDocument(
        uid: uid,
        bytes: idBytes,
        contentType: state.idDocumentContentType ?? 'image/jpeg',
      );
      final selfieUploadId = await uploads.uploadIdentityDocument(
        uid: uid,
        bytes: selfieBytes,
        contentType: state.selfieContentType ?? 'image/jpeg',
      );

      state = state.copyWith(status: IdentitySubmitStatus.submitting);
      final submissionId = await ref
          .read(identityVerificationRepositoryProvider)
          .submitIdentityVerification(
            idDocumentUploadId: idUploadId,
            selfieUploadId: selfieUploadId,
            documentType: state.documentType,
          );

      state = state.copyWith(
        status: IdentitySubmitStatus.submitted,
        submissionId: submissionId,
      );
      return true;
    } on IdentityCallableException catch (e) {
      // REVIEW_ALREADY_PENDING is not really a failure: it means a
      // submission this client lost track of is still open. Recover the
      // id and show the waiting state instead of an error the user can do
      // nothing about.
      if (e.code == 'REVIEW_ALREADY_PENDING') {
        await _adoptPendingAfterConflict(uid, e);
        return state.status == IdentitySubmitStatus.submitted;
      }
      state = state.copyWith(
        status: IdentitySubmitStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
      return false;
    } on Exception catch (e) {
      state = state.copyWith(
        status: IdentitySubmitStatus.failed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> _adoptPendingAfterConflict(
    String uid,
    IdentityCallableException e,
  ) async {
    try {
      final pending = await ref
          .read(identityVerificationRepositoryProvider)
          .fetchPendingSubmissionId(uid);
      if (pending != null) {
        state = state.copyWith(
          status: IdentitySubmitStatus.submitted,
          submissionId: pending,
        );
        return;
      }
    } on Exception {
      // Fall through to the error state below.
    }
    state = state.copyWith(
      status: IdentitySubmitStatus.failed,
      errorCode: e.code,
      errorMessage: e.message,
    );
  }
}

/// Streams the reviewer's verdict for a submission.
@riverpod
Stream<IdentityVerificationStatus> identityVerificationStatus(
  Ref ref,
  String submissionId,
) {
  return ref
      .read(identityVerificationRepositoryProvider)
      .watchSubmission(submissionId);
}
