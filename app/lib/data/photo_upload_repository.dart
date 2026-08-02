import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'photo_upload_repository.g.dart';

/// Cloud Storage access for the profile-photo upload path
/// (`users/{uid}/profile/pending/{uploadId}`, docs/FIREBASE.md §2.5,
/// docs/DATABASE.md §3.1a). Deliberately separate from
/// `UserProfileRepository`-style Firestore/Functions repositories, since
/// this wraps a different Firebase product with a different client SDK —
/// keeps each repository's constructor dependency-injectable independently
/// in tests, per docs/ENGINEERING_GUIDELINES.md's repository conventions.
///
/// Added Milestone F5.
class PhotoUploadRepository {
  /// Creates a repository over the given [storage] instance, defaulting to
  /// the app's real Firebase Storage instance.
  PhotoUploadRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const Uuid _uuid = Uuid();

  /// Uploads [bytes] to a freshly-minted pending path
  /// (`storage/storage.rules`'s owner-only, 10MB/image-type-capped
  /// `pending/` rule) and returns the generated `uploadId` — the caller
  /// needs it for both
  /// `UserProfileRepository.watchPhotoModerationStatus` and, once
  /// approved, `completeAccountSetup`'s `photoUploadId` field. Does not
  /// wait for moderation to complete — that's a separate, subsequent step,
  /// per docs/SCREEN_SPECIFICATIONS.md Screen 5's two-stage Loading States
  /// ("Uploading..." then "Reviewing your photo...").
  Future<String> uploadPendingProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uploadId = _uuid.v4();
    final ref = _storage.ref('users/$uid/profile/pending/$uploadId');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return uploadId;
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
PhotoUploadRepository photoUploadRepository(Ref ref) => PhotoUploadRepository();
