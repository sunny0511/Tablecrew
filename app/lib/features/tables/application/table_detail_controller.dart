import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/tables_repository.dart';

part 'table_detail_controller.g.dart';

/// Everything Table Detail (Screen 13) renders for one Table, from this
/// viewer's perspective.
class TableDetailData {
  /// Creates the loaded state.
  const TableDetailData({
    required this.table,
    required this.isHost,
    required this.myRsvpStatus,
    required this.attendees,
  });

  /// The Table.
  final TableSummary table;

  /// Whether the signed-in user hosts this Table.
  final bool isHost;

  /// This viewer's own RSVP status, or `null` if they have none.
  final RsvpStatus? myRsvpStatus;

  /// The full attendee list — only ever populated for the host (see
  /// [TablesRepository.fetchAttendees]'s doc comment for why a non-host
  /// can't list this at all); empty for every other viewer.
  final List<AttendeeSummary> attendees;
}

/// Loads Table Detail (Screen 13)'s data for [tableId]: the Table itself,
/// whether the viewer hosts it, their own RSVP status, and — host only —
/// the full attendee list.
///
/// A plain async build with no custom methods, same shape as
/// `HomeController`: actions live in the sibling
/// `TableDetailActionController`, which calls `ref.invalidate` on this
/// provider after a successful mutation to refresh (pull-to-refresh is
/// the same `ref.invalidate` from the widget).
///
/// Added Milestone F6.
@riverpod
class TableDetailController extends _$TableDetailController {
  @override
  Future<TableDetailData> build(String tableId) async {
    final uid = ref.watch(currentUidProvider);
    final tablesRepository = ref.read(tablesRepositoryProvider);

    final table = await tablesRepository.fetchTable(tableId);
    if (table == null) {
      throw StateError('Table $tableId not found or not readable.');
    }
    final isHost = table.hostId == uid;

    final (myRsvpStatus, attendees) = await (
      uid == null
          ? Future<RsvpStatus?>.value()
          : tablesRepository.fetchMyRsvpStatus(tableId, uid),
      isHost
          ? tablesRepository.fetchAttendees(tableId)
          : Future.value(const <AttendeeSummary>[]),
    ).wait;

    return TableDetailData(
      table: table,
      isHost: isHost,
      myRsvpStatus: myRsvpStatus,
      attendees: attendees,
    );
  }
}
