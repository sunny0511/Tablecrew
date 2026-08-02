import 'dart:typed_data';

import 'package:tablecrew/data/photo_upload_repository.dart';

/// Hand-written fake of [PhotoUploadRepository]
/// (`app/lib/data/photo_upload_repository.dart`). Unlike the three
/// repositories task #96 split into `abstract interface class`es, this one
/// is still a concrete class — but Dart's `implements` never runs the
/// implemented class's constructor, so this fake sidesteps the
/// `FirebaseStorage.instance`-in-initializer-list problem those splits
/// existed to solve without needing the split itself (only its single
/// public method is part of the implicit interface; the private `_storage`
/// field isn't). Used by Screen 5's widget tests (task #96e).
class FakePhotoUploadRepository implements PhotoUploadRepository {
  /// If set, [uploadPendingProfilePhoto] throws this instead of returning
  /// [nextUploadId] — simulates a network drop mid-upload.
  Exception? uploadError;

  /// The uploadId returned on success.
  String nextUploadId = 'upload-1';

  /// Every upload call's `(uid, byteCount, contentType)`, in order.
  final List<({String uid, int byteCount, String contentType})> uploads = [];

  @override
  Future<String> uploadPendingProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads.add(
      (uid: uid, byteCount: bytes.length, contentType: contentType),
    );
    final error = uploadError;
    if (error != null) throw error;
    return nextUploadId;
  }
}
