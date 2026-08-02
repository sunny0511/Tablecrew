import 'package:tablecrew/data/crews_repository.dart';

/// Hand-written fake of [CrewsRepository]
/// (`app/lib/data/crews_repository.dart`). Used by `HomeController`'s unit
/// tests and Home's widget tests (Milestone F6).
class FakeCrewsRepository implements CrewsRepository {
  /// What [fetchMyCrews] returns.
  List<CrewSummary> myCrews = [];

  /// If set, [fetchMyCrews] throws this instead.
  Exception? fetchError;

  /// What [fetchCrewMembers] resolves per `crewId`. An absent id resolves
  /// `null`.
  final Map<String, List<CrewMember>> crewMembersByCrewId = {};

  @override
  Future<List<CrewSummary>> fetchMyCrews(String uid) async {
    final error = fetchError;
    if (error != null) throw error;
    return myCrews;
  }

  @override
  Future<List<CrewMember>?> fetchCrewMembers(String crewId) async {
    final error = fetchError;
    if (error != null) throw error;
    return crewMembersByCrewId[crewId];
  }
}
