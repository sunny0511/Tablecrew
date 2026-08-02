import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';

/// Unit tests for [OnboardingProfileDraftController] — Milestone F5 task
/// #96. No Firebase dependency exists here at all (see the controller's own
/// doc comment: Screens 4/5 have nothing server-side to persist to
/// individually), so this needs no fake repository, only a
/// [ProviderContainer].
///
/// The one behavior worth deliberately testing rather than assuming:
/// [OnboardingProfileDraftController.setProfileFields] clears
/// `lastInitial`/`bio` when called again without them, unlike
/// `OnboardingPhoneFlowState.copyWith`'s default "leave unchanged" rule for
/// most fields — a real, easy-to-miss asymmetry between the two
/// controllers' `copyWith` conventions in this codebase.
void main() {
  late ProviderContainer container;
  late OnboardingProfileDraftController controller;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(onboardingProfileDraftControllerProvider, (_, __) {});
    controller = container.read(
      onboardingProfileDraftControllerProvider.notifier,
    );
  });

  OnboardingProfileDraft draft() =>
      container.read(onboardingProfileDraftControllerProvider);

  test('initial draft is empty', () {
    expect(draft().dateOfBirth, isNull);
    expect(draft().displayName, isNull);
    expect(draft().lastInitial, isNull);
    expect(draft().bio, isNull);
    expect(draft().photoUploadId, isNull);
    expect(draft().interestTags, isEmpty);
  });

  test('setDateOfBirth stages the date without touching other fields', () {
    final dob = DateTime(2000, 5);
    controller.setDateOfBirth(dob);

    expect(draft().dateOfBirth, dob);
    expect(draft().displayName, isNull);
  });

  test('setProfileFields stages all three fields when given', () {
    controller.setProfileFields(
      displayName: 'Ada',
      lastInitial: 'L',
      bio: 'Loves board games.',
    );

    expect(draft().displayName, 'Ada');
    expect(draft().lastInitial, 'L');
    expect(draft().bio, 'Loves board games.');
  });

  test(
    'setProfileFields clears a previously-staged lastInitial/bio when '
    'called again without them',
    () {
      controller
        ..setProfileFields(
          displayName: 'Ada',
          lastInitial: 'L',
          bio: 'Loves board games.',
        )
        // The second call, without lastInitial/bio, is the behavior under
        // test: it should clear both.
        ..setProfileFields(displayName: 'Ada');

      expect(draft().displayName, 'Ada');
      expect(draft().lastInitial, isNull);
      expect(draft().bio, isNull);
    },
  );

  test('setPhotoUploadId stages the id', () {
    controller.setPhotoUploadId('upload-123');

    expect(draft().photoUploadId, 'upload-123');
  });

  test('setInterestTags stages the selection', () {
    controller.setInterestTags(['coffee', 'hiking']);

    expect(draft().interestTags, ['coffee', 'hiking']);
  });

  test('reset discards every staged field back to initial', () {
    controller
      ..setDateOfBirth(DateTime(2000, 5))
      ..setProfileFields(displayName: 'Ada', lastInitial: 'L', bio: 'Hi')
      ..setPhotoUploadId('upload-123')
      ..setInterestTags(['coffee'])
      // The reset itself is the behavior under test.
      ..reset();

    expect(draft().dateOfBirth, isNull);
    expect(draft().displayName, isNull);
    expect(draft().lastInitial, isNull);
    expect(draft().bio, isNull);
    expect(draft().photoUploadId, isNull);
    expect(draft().interestTags, isEmpty);
  });
}
