import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_profile_draft_controller.g.dart';

/// The staged, not-yet-submitted account-creation draft spanning Screens
/// 4-6 (Date of Birth, Profile Setup, Interest Selection).
///
/// Exists because `completeAccountSetup` (docs/API_SPEC.md §3.9) is one
/// combined write, fired only once — at the end of Screen 6, per that
/// screen's own "API Calls" note ("fires the one combined call once
/// Profile Setup's fields are also ready"). Screens 4 and 5 have nothing
/// server-side to persist to individually; this class is where their
/// input lives until Screen 6's "Continue" submits everything together.
class OnboardingProfileDraft {
  /// Creates a draft. Prefer [OnboardingProfileDraft.initial] for the
  /// starting (empty) draft and [copyWith] for updates.
  const OnboardingProfileDraft({
    this.dateOfBirth,
    this.displayName,
    this.lastInitial,
    this.bio,
    this.photoUploadId,
    this.interestTags = const <String>[],
  });

  /// The empty starting draft.
  const OnboardingProfileDraft.initial() : this();

  /// Screen 4's staged date of birth.
  final DateTime? dateOfBirth;

  /// Screen 5's staged first name.
  final String? displayName;

  /// Screen 5's staged, optional last initial.
  final String? lastInitial;

  /// Screen 5's staged, optional bio (max 140 chars — enforced by the
  /// screen's own text field, not re-checked here).
  final String? bio;

  /// Screen 5's approved photo upload id, set only after
  /// `UserProfileRepository.watchPhotoModerationStatus` reports
  /// `"approved"` — never set from a raw, unmoderated upload.
  final String? photoUploadId;

  /// Screen 6's staged interest tag selection.
  final List<String> interestTags;

  /// Returns a copy with the given fields replaced. [clearLastInitial],
  /// [clearBio], and [clearPhotoUploadId] exist because `null` as a
  /// positional value can't be distinguished from "leave unchanged" for a
  /// nullable field.
  OnboardingProfileDraft copyWith({
    DateTime? dateOfBirth,
    String? displayName,
    String? lastInitial,
    String? bio,
    String? photoUploadId,
    List<String>? interestTags,
    bool clearLastInitial = false,
    bool clearBio = false,
    bool clearPhotoUploadId = false,
  }) {
    return OnboardingProfileDraft(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      displayName: displayName ?? this.displayName,
      lastInitial: clearLastInitial ? null : lastInitial ?? this.lastInitial,
      bio: clearBio ? null : bio ?? this.bio,
      photoUploadId:
          clearPhotoUploadId ? null : photoUploadId ?? this.photoUploadId,
      interestTags: interestTags ?? this.interestTags,
    );
  }
}

/// Holds the [OnboardingProfileDraft] across Screens 4-6's navigation —
/// see the class doc comment on [OnboardingProfileDraft] for why a shared
/// draft is needed at all.
///
/// **`keepAlive: true`, not the `@riverpod` autoDispose default — a real
/// bug found and fixed while writing this controller's tests (Milestone F5
/// task #96), not a defensive-only change.** Every call site
/// (`dob_entry_screen.dart`, `profile_setup_screen.dart`,
/// `interests_screen.dart`, `account_setup_controller.dart`) only ever
/// calls `ref.read(...)` on this provider, never `ref.watch(...)` —
/// confirmed against Riverpod's own docs, `ref.read` doesn't register a
/// listener, and an autoDispose provider with zero listeners for a full
/// frame has its state destroyed. With no `keepAlive`, that means this
/// controller was liable to be silently recreated back to
/// [OnboardingProfileDraft.initial] between screens, discarding whatever
/// had just been staged — plausibly on every real run, not as an edge
/// case, since nothing anywhere establishes a watch. `keepAlive: true`
/// matches `AccountSetupController`'s own stated reasoning for the same
/// annotation: this state has to "stay readable ... after that screen is
/// gone." [reset] already exists and is called once `completeAccountSetup`
/// actually succeeds, so a stale draft from an abandoned attempt doesn't
/// linger past a completed one.
///
/// Added Milestone F5.
@Riverpod(keepAlive: true)
class OnboardingProfileDraftController
    extends _$OnboardingProfileDraftController {
  @override
  OnboardingProfileDraft build() => const OnboardingProfileDraft.initial();

  /// Screen 4's "Continue" — stages the accepted date of birth.
  void setDateOfBirth(DateTime dateOfBirth) {
    state = state.copyWith(dateOfBirth: dateOfBirth);
  }

  /// Screen 5's "Continue" — stages the name/bio fields.
  void setProfileFields({
    required String displayName,
    String? lastInitial,
    String? bio,
  }) {
    state = state.copyWith(
      displayName: displayName,
      lastInitial: lastInitial,
      bio: bio,
      clearLastInitial: lastInitial == null,
      clearBio: bio == null,
    );
  }

  /// Screen 5's moderation-approved photo — see
  /// [OnboardingProfileDraft.photoUploadId]'s doc comment.
  void setPhotoUploadId(String photoUploadId) {
    state = state.copyWith(photoUploadId: photoUploadId);
  }

  /// Screen 6's staged interest selection.
  void setInterestTags(List<String> interestTags) {
    state = state.copyWith(interestTags: interestTags);
  }

  /// Discards the whole draft — called once `completeAccountSetup`
  /// actually succeeds (Screen 6), since nothing here is needed again.
  void reset() {
    state = const OnboardingProfileDraft.initial();
  }
}
