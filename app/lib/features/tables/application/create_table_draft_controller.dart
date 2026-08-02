import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:uuid/uuid.dart';

part 'create_table_draft_controller.g.dart';

/// Create Table (Screen 10)'s in-progress form draft. Unlike the
/// onboarding draft (`OnboardingProfileDraftController`, in-memory only —
/// see its doc comment), this one is **disk-persisted on every change**,
/// because Screen 10's Offline Behavior explicitly requires it: "The
/// entire form persists as a continuous local draft — every field change
/// saves to local storage immediately ... so backgrounding or losing
/// connectivity never loses in-progress input."
///
/// [draftId] doubles as the `OfflineMutationQueue` `mutationId` for this
/// draft's eventual `createTable` call — minted once when the draft is
/// first created and stable for the draft's whole life, which is exactly
/// what makes the offline-created Table's reconnect retry resolve to the
/// same idempotency key (docs/API_SPEC.md §2) instead of minting a
/// duplicate.
class CreateTableDraft {
  /// Creates a draft.
  const CreateTableDraft({
    required this.draftId,
    this.title = '',
    this.interestTag,
    this.venue,
    this.startTime,
    this.headcount,
    this.crewId,
  });

  /// Deserializes from [toJson]'s shape.
  factory CreateTableDraft.fromJson(Map<String, dynamic> json) {
    final venueJson = json['venue'] as Map<String, dynamic>?;
    final startMillis = json['startTime'] as int?;
    return CreateTableDraft(
      draftId: json['draftId'] as String,
      title: json['title'] as String? ?? '',
      interestTag: json['interestTag'] as String?,
      venue: venueJson == null ? null : VenueSelection.fromJson(venueJson),
      startTime: startMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startMillis),
      headcount: json['headcount'] as int?,
      crewId: json['crewId'] as String?,
    );
  }

  /// Stable id for this draft — also the `OfflineMutationQueue`
  /// mutationId; see the class doc comment.
  final String draftId;

  /// The Table's title.
  final String title;

  /// Selected interest tag, if any.
  final String? interestTag;

  /// Selected venue, if any.
  final VenueSelection? venue;

  /// Selected start date+time, if any.
  final DateTime? startTime;

  /// Selected headcount (capacity.max), or null until the user first
  /// touches the stepper (the activity-driven default applies then).
  final int? headcount;

  /// The Crew this draft was started from ("Schedule a Table"), if any.
  final String? crewId;

  /// Serializes for persistence.
  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'title': title,
      'interestTag': interestTag,
      'venue': venue?.toJson(),
      'startTime': startTime?.millisecondsSinceEpoch,
      'headcount': headcount,
      'crewId': crewId,
    };
  }

  /// Returns a copy with the given fields replaced.
  CreateTableDraft copyWith({
    String? title,
    String? interestTag,
    VenueSelection? venue,
    DateTime? startTime,
    int? headcount,
    String? crewId,
  }) {
    return CreateTableDraft(
      draftId: draftId,
      title: title ?? this.title,
      interestTag: interestTag ?? this.interestTag,
      venue: venue ?? this.venue,
      startTime: startTime ?? this.startTime,
      headcount: headcount ?? this.headcount,
      crewId: crewId ?? this.crewId,
    );
  }
}

/// Screen 10's activity-driven headcount recommendation
/// (`docs/SCREEN_SPECIFICATIONS.md` Create Table's UI Components):
/// Coffee/Mentorship 2-4 starting 3, Lunch 3-5 starting 4,
/// Dinner/Founder-dinners 4-6 starting 5, Board Games/Hiking 4-8 starting
/// 6 — absolute bounds hard-clamped 2-8 regardless. `mentorship` is listed
/// in the spec but absent from the enforced taxonomy
/// (`interest_taxonomy.dart`'s disclosed gap #2), so it's mapped here for
/// forward-compatibility but unreachable from the current chip set.
({int min, int max, int start}) recommendedHeadcountFor(String? interestTag) {
  return switch (interestTag) {
    'coffee' || 'mentorship' => (min: 2, max: 4, start: 3),
    'lunch' => (min: 3, max: 5, start: 4),
    'dinner' || 'founder_dinners' => (min: 4, max: 6, start: 5),
    'board_games' || 'hiking' => (min: 4, max: 8, start: 6),
    // No tag selected yet: the platform-wide default band.
    _ => (min: 2, max: 8, start: 4),
  };
}

/// Holds and continuously persists the Create Table draft — see
/// [CreateTableDraft]'s doc comment for why this one is disk-backed.
///
/// `keepAlive: true` for the same reason as the onboarding draft (every
/// call site `ref.read`s), though unlike that one, a mid-session dispose
/// here would only cost an in-memory copy — the disk draft reloads.
///
/// Added Milestone F6.
@Riverpod(keepAlive: true)
class CreateTableDraftController extends _$CreateTableDraftController {
  static const _prefsKey = 'tables.createTableDraftV1';
  static const _uuid = Uuid();

  @override
  Future<CreateTableDraft> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      return CreateTableDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    return CreateTableDraft(draftId: _uuid.v4());
  }

  Future<void> _update(
    CreateTableDraft Function(CreateTableDraft draft) transform,
  ) async {
    final current = await future;
    final next = transform(current);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }

  /// Stages the title.
  Future<void> setTitle(String title) =>
      _update((draft) => draft.copyWith(title: title));

  /// Stages the interest tag.
  Future<void> setInterestTag(String interestTag) =>
      _update((draft) => draft.copyWith(interestTag: interestTag));

  /// Stages the venue selected in Venue Picker.
  Future<void> setVenue(VenueSelection venue) =>
      _update((draft) => draft.copyWith(venue: venue));

  /// Stages the start date+time.
  Future<void> setStartTime(DateTime startTime) =>
      _update((draft) => draft.copyWith(startTime: startTime));

  /// Stages the headcount.
  Future<void> setHeadcount(int headcount) =>
      _update((draft) => draft.copyWith(headcount: headcount));

  /// Stages the originating Crew ("Schedule a Table" entry point).
  Future<void> setCrewId(String crewId) =>
      _update((draft) => draft.copyWith(crewId: crewId));

  /// Discards the draft entirely (successful creation, or an explicit
  /// user discard) and mints a fresh draftId for the next one.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = AsyncData(CreateTableDraft(draftId: _uuid.v4()));
  }
}
