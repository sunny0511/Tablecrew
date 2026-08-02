import 'dart:async';

import 'package:tablecrew/data/user_profile_repository.dart';

/// Hand-written fake of [UserProfileRepository]
/// (`app/lib/data/user_profile_repository.dart`) — `implements` the
/// interface directly, touching no Firestore/Functions SDK type at all.
/// Used by `AccountSetupController`'s tests (Milestone F5 task #96) and
/// the onboarding screens' widget tests (task #96e), whose Screen 5 tests
/// drive the [watchPhotoModerationStatus] stream via
/// [emitModerationStatus].
class FakeUserProfileRepository implements UserProfileRepository {
  /// What [hasCompletedProfile] returns, keyed by uid. A uid missing from
  /// this map is treated as "no profile" (`false`), the common case for a
  /// test that only cares about one uid.
  final Map<String, bool> completedProfiles = {};

  /// What [validateAge] returns. Defaults to `true` (eligible) since most
  /// tests aren't specifically exercising the under-18 path.
  bool validateAgeResult = true;

  /// If set, [completeAccountSetup] throws this instead of returning
  /// [completeAccountSetupResult].
  Exception? completeAccountSetupError;

  /// What [completeAccountSetup] returns on success.
  CompleteAccountSetupResult completeAccountSetupResult =
      const CompleteAccountSetupResult(
    uid: 'uid-fake',
    verificationTierPublic: 'unverified',
  );

  /// Every [completeAccountSetup] call's arguments, in order — lets tests
  /// assert on exactly what was sent without re-deriving it from an
  /// `OnboardingProfileDraft` themselves.
  final List<
      ({
        DateTime dateOfBirth,
        String displayName,
        List<String> interestTags,
        String locale,
        String? photoUploadId,
        String? bio,
      })> completeAccountSetupCalls = [];

  final Map<String, StreamController<PhotoModerationStatus>>
      _moderationControllers = {};

  @override
  Future<bool> hasCompletedProfile(String uid) async =>
      completedProfiles[uid] ?? false;

  @override
  Future<bool> validateAge(DateTime dateOfBirth) async => validateAgeResult;

  @override
  Future<CompleteAccountSetupResult> completeAccountSetup({
    required DateTime dateOfBirth,
    required String displayName,
    required List<String> interestTags,
    required String locale,
    String? photoUploadId,
    String? bio,
  }) async {
    completeAccountSetupCalls.add(
      (
        dateOfBirth: dateOfBirth,
        displayName: displayName,
        interestTags: interestTags,
        locale: locale,
        photoUploadId: photoUploadId,
        bio: bio,
      ),
    );
    final error = completeAccountSetupError;
    if (error != null) throw error;
    return completeAccountSetupResult;
  }

  @override
  Stream<PhotoModerationStatus> watchPhotoModerationStatus({
    required String uid,
    required String uploadId,
  }) {
    return _moderationControllerFor(uid, uploadId).stream;
  }

  /// Pushes a moderation [status] to whatever's currently listening via
  /// [watchPhotoModerationStatus] for `(uid, uploadId)` — the test-side
  /// hook for simulating the Storage-triggered Cloud Function's verdict
  /// arriving.
  void emitModerationStatus(
    String uid,
    String uploadId,
    PhotoModerationStatus status,
  ) {
    _moderationControllerFor(uid, uploadId).add(status);
  }

  /// Closes every moderation-status stream this fake opened — call from a
  /// test's `tearDown`/`addTearDown`.
  Future<void> dispose() async {
    for (final controller in _moderationControllers.values) {
      await controller.close();
    }
  }

  StreamController<PhotoModerationStatus> _moderationControllerFor(
    String uid,
    String uploadId,
  ) {
    final key = '$uid/$uploadId';
    return _moderationControllers.putIfAbsent(
      key,
      StreamController<PhotoModerationStatus>.broadcast,
    );
  }
}
