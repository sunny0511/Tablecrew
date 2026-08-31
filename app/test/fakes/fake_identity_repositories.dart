import 'dart:async';
import 'dart:typed_data';

import 'package:tablecrew/data/identity_upload_repository.dart';
import 'package:tablecrew/data/identity_verification_repository.dart';

/// Hand-written fake of [IdentityUploadRepository]
/// (`app/lib/data/identity_upload_repository.dart`), Milestone F7.
class FakeIdentityUploadRepository implements IdentityUploadRepository {
  /// Upload ids handed out in order; reused once exhausted.
  final List<String> uploadIds = ['upload-1', 'upload-2'];

  /// If set, [uploadIdentityDocument] throws this instead.
  Exception? uploadError;

  /// Every call's arguments, in order.
  final List<({String uid, int byteCount, String contentType})> calls = [];

  int _next = 0;

  @override
  Future<String> uploadIdentityDocument({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add(
      (uid: uid, byteCount: bytes.length, contentType: contentType),
    );
    final error = uploadError;
    if (error != null) throw error;
    final id = uploadIds[_next % uploadIds.length];
    _next++;
    return id;
  }
}

/// Hand-written fake of [IdentityVerificationRepository], Milestone F7.
class FakeIdentityVerificationRepository
    implements IdentityVerificationRepository {
  /// What [submitIdentityVerification] returns on success.
  String submissionIdResult = 'submission-fake';

  /// If set, [submitIdentityVerification] throws this instead.
  Exception? submitError;

  /// What [fetchPendingSubmissionId] returns.
  String? pendingSubmissionId;

  /// If set, [fetchPendingSubmissionId] throws this instead.
  Exception? pendingError;

  /// If set, [watchSubmission] returns a single-value stream of this
  /// instead of [statusController]'s. Widget tests want a status that is
  /// already there when the screen first builds; a broadcast controller
  /// does not replay, so seeding it that way would race the first frame.
  IdentityVerificationStatus? statusSeed;

  /// Drives [watchSubmission] when [statusSeed] is null.
  final StreamController<IdentityVerificationStatus> statusController =
      StreamController<IdentityVerificationStatus>.broadcast();

  /// Every [submitIdentityVerification] call's arguments, in order.
  final List<
      ({
        String idDocumentUploadId,
        String selfieUploadId,
        IdentityDocumentType documentType,
      })> submitCalls = [];

  @override
  Future<String> submitIdentityVerification({
    required String idDocumentUploadId,
    required String selfieUploadId,
    required IdentityDocumentType documentType,
  }) async {
    submitCalls.add(
      (
        idDocumentUploadId: idDocumentUploadId,
        selfieUploadId: selfieUploadId,
        documentType: documentType,
      ),
    );
    final error = submitError;
    if (error != null) throw error;
    return submissionIdResult;
  }

  @override
  Future<String?> fetchPendingSubmissionId(String uid) async {
    final error = pendingError;
    if (error != null) throw error;
    return pendingSubmissionId;
  }

  @override
  Stream<IdentityVerificationStatus> watchSubmission(String submissionId) {
    final seed = statusSeed;
    return seed == null
        ? statusController.stream
        : Stream<IdentityVerificationStatus>.value(seed);
  }
}
