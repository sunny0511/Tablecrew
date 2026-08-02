import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/application/table_detail_controller.dart';

import '../../../fakes/fake_tables_repository.dart';

/// Unit tests for [TableDetailController]'s load/merge logic — Milestone
/// F6.
void main() {
  late FakeTablesRepository tablesRepository;
  late ProviderContainer container;

  ProviderContainer buildContainer({String? uid = 'me'}) {
    final built = ProviderContainer(
      overrides: [
        tablesRepositoryProvider.overrideWithValue(tablesRepository),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    tablesRepository = FakeTablesRepository();
  });

  test('the host sees isHost true and the full attendee list', () async {
    tablesRepository.tablesById['t1'] =
        buildTestTableSummary(id: 't1', hostId: 'me');
    tablesRepository.attendeesByTableId['t1'] = const [
      AttendeeSummary(
        uid: 'bob',
        displayName: 'Bob',
        status: RsvpStatus.requested,
      ),
    ];
    container = buildContainer();

    final data =
        await container.read(tableDetailControllerProvider('t1').future);

    expect(data.isHost, isTrue);
    expect(data.attendees, hasLength(1));
    expect(data.attendees.single.displayName, 'Bob');
  });

  test(
      'a non-host sees isHost false, their own rsvp status, and no '
      'attendee list', () async {
    tablesRepository.tablesById['t1'] = buildTestTableSummary(id: 't1');
    tablesRepository.myRsvpStatusByTableId['t1'] = RsvpStatus.confirmed;
    tablesRepository.attendeesByTableId['t1'] = const [
      AttendeeSummary(
        uid: 'me',
        displayName: 'Me',
        status: RsvpStatus.confirmed,
      ),
    ];
    container = buildContainer();

    final data =
        await container.read(tableDetailControllerProvider('t1').future);

    expect(data.isHost, isFalse);
    expect(data.myRsvpStatus, RsvpStatus.confirmed);
    expect(
      data.attendees,
      isEmpty,
      reason: 'fetchAttendees is host-only — a non-host must never even '
          'attempt the rules-denied list query',
    );
  });

  test('a non-host with no rsvp sees a null myRsvpStatus', () async {
    tablesRepository.tablesById['t1'] = buildTestTableSummary(id: 't1');
    container = buildContainer();

    final data =
        await container.read(tableDetailControllerProvider('t1').future);

    expect(data.myRsvpStatus, isNull);
  });

  test('a missing/unreadable Table surfaces as a load error', () async {
    container = buildContainer();

    await expectLater(
      container.read(tableDetailControllerProvider('missing').future),
      throwsA(isA<StateError>()),
    );
  });
}
