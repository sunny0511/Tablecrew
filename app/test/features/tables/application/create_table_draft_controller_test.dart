import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/application/create_table_draft_controller.dart';

/// Unit tests for [CreateTableDraftController] and
/// [recommendedHeadcountFor] — Milestone F6.
///
/// Every mutating test re-reads via a fresh [ProviderContainer] afterward
/// to prove persistence actually round-trips through the real
/// `SharedPreferences` mock store (not just in-memory state), matching
/// Screen 10's Offline Behavior requirement that a draft survive an app
/// restart.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('recommendedHeadcountFor', () {
    test('maps each activity to its documented band and start value', () {
      expect(recommendedHeadcountFor('coffee'), (min: 2, max: 4, start: 3));
      expect(recommendedHeadcountFor('lunch'), (min: 3, max: 5, start: 4));
      expect(recommendedHeadcountFor('dinner'), (min: 4, max: 6, start: 5));
      expect(
        recommendedHeadcountFor('founder_dinners'),
        (min: 4, max: 6, start: 5),
      );
      expect(
        recommendedHeadcountFor('board_games'),
        (min: 4, max: 8, start: 6),
      );
      expect(recommendedHeadcountFor('hiking'), (min: 4, max: 8, start: 6));
    });

    test('falls back to the platform-wide band with no tag selected', () {
      expect(recommendedHeadcountFor(null), (min: 2, max: 8, start: 4));
      expect(
        recommendedHeadcountFor('unknown_tag'),
        (min: 2, max: 8, start: 4),
      );
    });
  });

  group('CreateTableDraftController', () {
    test('mints a fresh draftId with no persisted draft', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draft =
          await container.read(createTableDraftControllerProvider.future);

      expect(draft.draftId, isNotEmpty);
      expect(draft.title, isEmpty);
      expect(draft.venue, isNull);
    });

    test('stages every field and persists across a fresh container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier =
          container.read(createTableDraftControllerProvider.notifier);
      await container.read(createTableDraftControllerProvider.future);

      await notifier.setTitle('Board Games Night');
      await notifier.setInterestTag('board_games');
      await notifier.setVenue(
        const VenueSelection(name: 'Cafe Coffee Day', address: '123 Main St'),
      );
      final start = DateTime(2026, 9, 20, 19);
      await notifier.setStartTime(start);
      await notifier.setHeadcount(7);
      await notifier.setCrewId('crew-1');

      final draftId =
          (await container.read(createTableDraftControllerProvider.future))
              .draftId;

      // Simulate an app restart: a fresh container re-reads the same
      // (mocked) SharedPreferences store rather than sharing this
      // container's in-memory provider state.
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      final reloaded =
          await restarted.read(createTableDraftControllerProvider.future);

      expect(reloaded.draftId, draftId);
      expect(reloaded.title, 'Board Games Night');
      expect(reloaded.interestTag, 'board_games');
      expect(reloaded.venue?.name, 'Cafe Coffee Day');
      expect(reloaded.venue?.address, '123 Main St');
      expect(reloaded.startTime, start);
      expect(reloaded.headcount, 7);
      expect(reloaded.crewId, 'crew-1');
    });

    test('clear() discards the draft and mints a new draftId', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier =
          container.read(createTableDraftControllerProvider.notifier);
      await container.read(createTableDraftControllerProvider.future);
      await notifier.setTitle('Old Draft');
      final oldDraftId =
          (await container.read(createTableDraftControllerProvider.future))
              .draftId;

      await notifier.clear();

      final cleared =
          await container.read(createTableDraftControllerProvider.future);
      expect(cleared.draftId, isNot(oldDraftId));
      expect(cleared.title, isEmpty);

      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      final reloaded =
          await restarted.read(createTableDraftControllerProvider.future);
      expect(reloaded.title, isEmpty, reason: 'clear() must persist too');
    });
  });
}
