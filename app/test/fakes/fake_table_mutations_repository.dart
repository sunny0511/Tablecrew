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
}
