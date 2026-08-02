import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'crews_repository.g.dart';

/// The slice of a `crews/{crewId}` document (`docs/DATABASE.md` §3.4)
/// Home's Crew Cards need — full Crew detail belongs to F8's Crew
/// management screens, not this milestone.
class CrewSummary {
  /// Creates a summary. See [CrewSummary.fromDoc] for the wire mapping.
  const CrewSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    this.photoUrl,
  });

  /// Maps a Firestore document to a summary.
  factory CrewSummary.fromDoc(String id, Map<String, dynamic> data) {
    final memberIds = data['memberIds'] as List<dynamic>?;
    return CrewSummary(
      id: id,
      name: data['name'] as String? ?? '',
      memberCount: memberIds?.length ?? 0,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  /// The document id.
  final String id;

  /// The Crew's display name.
  final String name;

  /// How many members the Crew has (`memberIds.length`).
  final int memberCount;

  /// The Crew's photo, if set.
  final String? photoUrl;
}

/// Firestore reads for the `crews` collection that Home (Screen 9) needs.
/// Same interface/implementation split and read-only posture as
/// [`TablesRepository`] (`tables_repository.dart`) — every Crew mutation
/// goes through the F4 callables (`createCrew`/`addMember`/...), except
/// the narrow admin-only name/photo direct-edit `firestore.rules` allows,
/// which no Home surface performs.
///
/// Added Milestone F6.
// One member today, but this stays a repository interface, not a top-level
// function: F8's Crew management adds more reads here, and the
// interface/impl split is what lets tests fake it without Firestore (the
// same reasoning as every other repository in this codebase).
// ignore: one_member_abstracts
abstract interface class CrewsRepository {
  /// Crews the user belongs to — `crews where memberIds array-contains
  /// uid`, the exact query shape `firestore.rules`' crews read rule
  /// (`request.auth.uid in resource.data.memberIds`) provably allows.
  Future<List<CrewSummary>> fetchMyCrews(String uid);
}

/// The real, Firestore-backed [CrewsRepository].
class FirestoreCrewsRepository implements CrewsRepository {
  /// Creates a repository over [firestore], defaulting to the app's real
  /// instance.
  FirestoreCrewsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<CrewSummary>> fetchMyCrews(String uid) async {
    final snapshot = await _firestore
        .collection('crews')
        .where('memberIds', arrayContains: uid)
        .get();
    return [
      for (final doc in snapshot.docs) CrewSummary.fromDoc(doc.id, doc.data()),
    ];
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
CrewsRepository crewsRepository(Ref ref) => FirestoreCrewsRepository();
