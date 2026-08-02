import 'package:tablecrew/data/tables_repository.dart';

/// Hand-written fake of [TablesRepository]
/// (`app/lib/data/tables_repository.dart`) — `implements` the interface
/// directly, touching no Firestore type. Used by `HomeController`'s unit
/// tests and Home's widget tests (Milestone F6).
class FakeTablesRepository implements TablesRepository {
  /// What [fetchHostedTables] returns.
  List<TableSummary> hostedTables = [];

  /// What [fetchMyRsvps] returns.
  List<MyRsvp> myRsvps = [];

  /// What [fetchTable] resolves per id — an absent id resolves `null`,
  /// mirroring the real implementation's deleted/unreadable mapping.
  final Map<String, TableSummary> tablesById = {};

  /// If set, every fetch throws this — for error-state tests.
  Exception? fetchError;

  @override
  Future<List<TableSummary>> fetchHostedTables(String uid) async {
    final error = fetchError;
    if (error != null) throw error;
    return hostedTables;
  }

  @override
  Future<List<MyRsvp>> fetchMyRsvps(String uid) async {
    final error = fetchError;
    if (error != null) throw error;
    return myRsvps;
  }

  @override
  Future<TableSummary?> fetchTable(String tableId) async {
    final error = fetchError;
    if (error != null) throw error;
    return tablesById[tableId];
  }
}

/// Builds a [TableSummary] with test defaults — override just the fields
/// a test cares about, same shape as `functions/test/fixtures/`'s
/// builders.
TableSummary buildTestTableSummary({
  String id = 'table-1',
  String hostId = 'host-1',
  String title = 'Test Table',
  TableStatus status = TableStatus.filling,
  DateTime? startTime,
  int confirmedCount = 2,
  int capacityMax = 6,
  String? interestTag,
  String? venueName,
}) {
  return TableSummary(
    id: id,
    hostId: hostId,
    title: title,
    status: status,
    startTime: startTime ?? DateTime(2026, 9, 15, 19),
    confirmedCount: confirmedCount,
    capacityMax: capacityMax,
    interestTag: interestTag,
    venueName: venueName,
  );
}
