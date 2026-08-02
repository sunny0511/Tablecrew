import 'package:tablecrew/data/table_mutations_repository.dart';

/// Hand-written fake of [TableMutationsRepository]
/// (`app/lib/data/table_mutations_repository.dart`). Used by
/// `CreateTableController`'s tests (Milestone F6).
class FakeTableMutationsRepository implements TableMutationsRepository {
  /// What [createTable] returns on success.
  CreateTableResult createTableResult = const CreateTableResult(
    tableId: 'table-fake',
    status: 'proposed',
  );

  /// If set, [createTable] throws this instead of returning
  /// [createTableResult].
  Exception? createTableError;

  /// Every [createTable] call's arguments, in order.
  final List<
      ({
        String title,
        String visibility,
        VenueSelection venue,
        DateTime startTime,
        int capacityMin,
        int capacityMax,
        String idempotencyKey,
        String? interestTag,
        String? description,
        String? crewId,
      })> createTableCalls = [];

  @override
  Future<CreateTableResult> createTable({
    required String title,
    required String visibility,
    required VenueSelection venue,
    required DateTime startTime,
    required int capacityMin,
    required int capacityMax,
    required String idempotencyKey,
    String? interestTag,
    String? description,
    String? crewId,
  }) async {
    createTableCalls.add(
      (
        title: title,
        visibility: visibility,
        venue: venue,
        startTime: startTime,
        capacityMin: capacityMin,
        capacityMax: capacityMax,
        idempotencyKey: idempotencyKey,
        interestTag: interestTag,
        description: description,
        crewId: crewId,
      ),
    );
    final error = createTableError;
    if (error != null) throw error;
    return createTableResult;
  }

  /// What [requestSeat] returns on success.
  RequestSeatResult requestSeatResult = const RequestSeatResult('requested');

  /// If set, [requestSeat] throws this instead.
  Exception? requestSeatError;

  /// Every [requestSeat] call's `(tableId, idempotencyKey)`, in order.
  final List<({String tableId, String idempotencyKey})> requestSeatCalls = [];

  @override
  Future<RequestSeatResult> requestSeat({
    required String tableId,
    required String idempotencyKey,
  }) async {
    requestSeatCalls.add((tableId: tableId, idempotencyKey: idempotencyKey));
    final error = requestSeatError;
    if (error != null) throw error;
    return requestSeatResult;
  }

  /// If set, [cancelRsvp] throws this instead of succeeding.
  Exception? cancelRsvpError;

  /// Every [cancelRsvp] call's `(tableId, idempotencyKey)`, in order.
  final List<({String tableId, String idempotencyKey})> cancelRsvpCalls = [];

  @override
  Future<void> cancelRsvp({
    required String tableId,
    required String idempotencyKey,
  }) async {
    cancelRsvpCalls.add((tableId: tableId, idempotencyKey: idempotencyKey));
    final error = cancelRsvpError;
    if (error != null) throw error;
  }

  /// If set, [confirmAttendee] throws this instead of succeeding.
  Exception? confirmAttendeeError;

  /// Every [confirmAttendee] call's arguments, in order.
  final List<({String tableId, String targetUserId, String idempotencyKey})>
      confirmAttendeeCalls = [];

  @override
  Future<void> confirmAttendee({
    required String tableId,
    required String targetUserId,
    required String idempotencyKey,
  }) async {
    confirmAttendeeCalls.add(
      (
        tableId: tableId,
        targetUserId: targetUserId,
        idempotencyKey: idempotencyKey,
      ),
    );
    final error = confirmAttendeeError;
    if (error != null) throw error;
  }

  /// If set, [cancelTable] throws this instead of succeeding.
  Exception? cancelTableError;

  /// Every [cancelTable] call's `(tableId, reason)`, in order.
  final List<({String tableId, String? reason})> cancelTableCalls = [];

  @override
  Future<void> cancelTable({required String tableId, String? reason}) async {
    cancelTableCalls.add((tableId: tableId, reason: reason));
    final error = cancelTableError;
    if (error != null) throw error;
  }
}
