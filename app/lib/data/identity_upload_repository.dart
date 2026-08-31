import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'identity_upload_repository.g.dart';

/// Cloud Storage access for the Tier 2 identity-verification upload path
/// (`identity-verifications/{uid}/{uploadId}`, `storage/storage.rules`,
/// docs/DATABASE.md §3.10, ADR 0007). Separate from
/// [IdentityVerificationRepository] for the same reason
/// `PhotoUploadRepository` is separate from `UserProfileRepository`: it
/// wraps a different Firebase product with a different client SDK, and
/// keeping them apart keeps each independently injectable in tests.
///
/// Added Milestone F7.
///
/// One difference from the profile-photo path worth knowing before
/// changing anything here: these objects are **write-only for the client**.
/// `storage.rules` grants `create` and denies `read` to everyone including
/// the uploader, so there is deliberately no "fetch it back" method on this
/// repository and no code path that could grow one by accident. Screen 8
/// previews the captured image from the local capture buffer, never from a
/// round trip. See docs/DATABASE.md §6's note on why: a user has no reason
/// to download their own government ID out of our bucket, and permitting it
/// would turn a stolen session token into ID exfiltration.
abstract interface class IdentityUploadRepository {
  /// Uploads [bytes] to a freshly-minted path under the caller's own
  /// prefix and returns the generated `uploadId`, which
  /// `submitIdentityVerification` takes as
  /// `idDocumentUploadId`/`selfieUploadId` (docs/API_SPEC.md §3.7).
  ///
  /// The server rebuilds the full path from `context.auth.uid` and this id
  /// rather than trusting a client-supplied path, so [uid] here only has
  /// to match the signed-in user for the write to satisfy the rules.
  Future<String> uploadIdentityDocument({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  });
}

/// Real Firebase Storage implementation of [IdentityUploadRepository].
class FirebaseIdentityUploadRepository implements IdentityUploadRepository {
  /// Creates a repository over the given [storage] instance, defaulting to
  /// the app's real Firebase Storage instance.
  FirebaseIdentityUploadRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const Uuid _uuid = Uuid();

  @override
  Future<String> uploadIdentityDocument({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // A v4 UUID satisfies functions/src/identity/validation.ts's
    // isValidUploadId (alphanumerics and hyphens, well under 128 chars) —
    // that validator rejects path separators and dot segments outright
    // rather than sanitizing them, so an id generated any other way should
    // be checked against it before being used here.
    final uploadId = _uuid.v4();
    final ref = _storage.ref('identity-verifications/$uid/$uploadId');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return uploadId;
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
IdentityUploadRepository identityUploadRepository(Ref ref) =>
    FirebaseIdentityUploadRepository();
