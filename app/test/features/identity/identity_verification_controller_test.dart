import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablecrew/data/identity_upload_repository.dart';
import 'package:tablecrew/data/identity_verification_repository.dart';
import 'package:tablecrew/features/identity/application/identity_verification_controller.dart';

import '../../fakes/fake_identity_repositories.dart';

void main() {
  late FakeIdentityUploadRepository uploads;
  late FakeIdentityVerificationRepository verification;
  late ProviderContainer container;

  setUp(() {
    uploads = FakeIdentityUploadRepository();
    verification = FakeIdentityVerificationRepository();
    container = ProviderContainer(
      overrides: [
        identityUploadRepositoryProvider.overrideWithValue(uploads),
        identityVerificationRepositoryProvider.overrideWithValue(verification),
      ],
    );
    addTearDown(container.dispose);
  });

  IdentityVerificationController controller() =>
      container.read(identityVerificationControllerProvider.notifier);

  IdentityVerificationState state() =>
      container.read(identityVerificationControllerProvider);

  void captureBoth() {
    controller()
      ..setIdDocument(Uint8List.fromList([1, 2, 3]), 'image/jpeg')
      ..setSelfie(Uint8List.fromList([4, 5, 6]), 'image/png');
  }

  test('canSubmit is false until both images are captured', () {
    expect(state().canSubmit, isFalse);
    controller().setIdDocument(Uint8List.fromList([1]), 'image/jpeg');
    expect(state().canSubmit, isFalse);
    controller().setSelfie(Uint8List.fromList([2]), 'image/jpeg');
    expect(state().canSubmit, isTrue);
  });

  test('submit uploads both images then submits, and records the id', () async {
    captureBoth();
    final ok = await controller().submit('alice');

    expect(ok, isTrue);
    expect(uploads.calls, hasLength(2));
    expect(uploads.calls.every((c) => c.uid == 'alice'), isTrue);
    // Content types are carried through, not defaulted away.
    expect(uploads.calls.first.contentType, 'image/jpeg');
    expect(uploads.calls.last.contentType, 'image/png');

    expect(verification.submitCalls, hasLength(1));
    expect(verification.submitCalls.single.idDocumentUploadId, 'upload-1');
    expect(verification.submitCalls.single.selfieUploadId, 'upload-2');
    expect(state().status, IdentitySubmitStatus.submitted);
    expect(state().submissionId, 'submission-fake');
  });

  test('submit does nothing without both images', () async {
    controller().setIdDocument(Uint8List.fromList([1]), 'image/jpeg');
    expect(await controller().submit('alice'), isFalse);
    expect(uploads.calls, isEmpty);
    expect(verification.submitCalls, isEmpty);
  });

  test('a known callable failure surfaces its code', () async {
    captureBoth();
    verification.submitError = const IdentityCallableException(
      code: 'RATE_LIMITED',
      message: 'Too many attempts.',
    );

    expect(await controller().submit('alice'), isFalse);
    expect(state().status, IdentitySubmitStatus.failed);
    expect(state().errorCode, 'RATE_LIMITED');
  });

  test(
      'REVIEW_ALREADY_PENDING adopts the open submission instead of erroring',
      () async {
    // The recovery path that exists because the client can lose the id:
    // this is not a failure the user can act on, it means a review they
    // already started is still open.
    captureBoth();
    verification.submitError = const IdentityCallableException(
      code: 'REVIEW_ALREADY_PENDING',
      message: 'A review is already pending.',
    );
    verification.pendingSubmissionId = 'submission-open';

    final ok = await controller().submit('alice');

    expect(ok, isTrue);
    expect(state().status, IdentitySubmitStatus.submitted);
    expect(state().submissionId, 'submission-open');
    expect(state().errorCode, isNull);
  });

  test(
      'REVIEW_ALREADY_PENDING with no recoverable id falls back to an error',
      () async {
    captureBoth();
    verification.submitError = const IdentityCallableException(
      code: 'REVIEW_ALREADY_PENDING',
      message: 'A review is already pending.',
    );
    verification.pendingSubmissionId = null;

    expect(await controller().submit('alice'), isFalse);
    expect(state().status, IdentitySubmitStatus.failed);
    expect(state().errorCode, 'REVIEW_ALREADY_PENDING');
  });

  test('restorePendingSubmission adopts an open review after a restart',
      () async {
    verification.pendingSubmissionId = 'submission-open';
    await controller().restorePendingSubmission('alice');

    expect(state().status, IdentitySubmitStatus.submitted);
    expect(state().submissionId, 'submission-open');
  });

  test('restorePendingSubmission with nothing open returns to capture',
      () async {
    verification.pendingSubmissionId = null;
    await controller().restorePendingSubmission('alice');

    expect(state().status, IdentitySubmitStatus.idle);
    expect(state().submissionId, isNull);
  });

  test('a failed restore lookup does not strand the user on a spinner',
      () async {
    verification.pendingError = Exception('offline');
    await controller().restorePendingSubmission('alice');

    expect(state().status, IdentitySubmitStatus.idle);
  });

  test('reset clears captures so "Try again" starts clean', () async {
    captureBoth();
    await controller().submit('alice');
    controller().reset();

    expect(state().status, IdentitySubmitStatus.idle);
    expect(state().submissionId, isNull);
    expect(state().idDocumentBytes, isNull);
    expect(state().selfieBytes, isNull);
  });
}
