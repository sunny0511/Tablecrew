import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tables_repository.g.dart';

/// A Table document's lifecycle status (`docs/DATABASE.md` §3.2's enum),
/// parsed from the wire string. [unknown] absorbs any value a newer
/// backend might write that this client build doesn't know yet — rendering
/// a neutral card beats crashing the Home list on one unrecognized doc.
enum TableStatus {
  /// `"proposed"`.
  proposed,

  /// `"filling"`.
  filling,

  /// `"confirmed"`.
  confirmed,

  /// `"happened"`.
  happened,

  /// `"rated"`.
  rated,

  /// `"cancelled"`.
  cancelled,

  /// Any unrecognized wire value.
  unknown;

  /// Parses the Firestore wire string.
  static TableStatus fromWire(String? value) {
    return switch (value) {
      'proposed' => TableStatus.proposed,
      'filling' => TableStatus.filling,
      'confirmed' => TableStatus.confirmed,
      'happened' => TableStatus.happened,
      'rated' => TableStatus.rated,
      'cancelled' => TableStatus.cancelled,
      _ => TableStatus.unknown,
    };
  }
}

/// An RSVP document's status (`docs/DATABASE.md` §3.3's enum), parsed from
/// the wire string — same [unknown]-absorbs-new-values reasoning as
/// [TableStatus].
enum RsvpStatus {
  /// `"invited"`.
  invited,

  /// `"requested"`.
  requested,

  /// `"confirmed"`.
  confirmed,

  /// `"declined"`.
  declined,

  /// `"waitlisted"`.
  waitlisted,

  /// `"attended"`.
  attended,

  /// `"no_show"`.
  noShow,

  /// Any unrecognized wire value.
  unknown;

  /// Parses the Firestore wire string.
  static RsvpStatus fromWire(String? value) {
    return switch (value) {
      'invited' => RsvpStatus.invited,
      'requested' => RsvpStatus.requested,
      'confirmed' => RsvpStatus.confirmed,
      'declined' => RsvpStatus.declined,
      'waitlisted' => RsvpStatus.waitlisted,
      'attended' => RsvpStatus.attended,
      'no_show' => RsvpStatus.noShow,
      _ => RsvpStatus.unknown,
    };
  }
}

/// The slice of a `tables/{tableId}` document (`docs/DATABASE.md` §3.2)
/// Home's Table Cards need — deliberately not the full document model,
/// which belongs to the Table Detail milestone chunk that actually renders
/// every field.
class TableSummary {
  /// Creates a summary. See [TableSummary.fromDoc] for the wire mapping.
  const TableSummary({
    required this.id,
    required this.hostId,
    required this.title,
    required this.status,
    required this.startTime,
    required this.confirmedCount,
    required this.capacityMax,
    this.interestTag,
    this.venueName,
  });

  /// Maps a Firestore document to a summary.
  factory TableSummary.fromDoc(String id, Map<String, dynamic> data) {
    final location = data['location'] as Map<String, dynamic>?;
    final capacity = data['capacity'] as Map<String, dynamic>?;
    return TableSummary(
      id: id,
      hostId: data['hostId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      status: TableStatus.fromWire(data['status'] as String?),
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime(1970),
      confirmedCount: (capacity?['confirmedCount'] as num?)?.toInt() ?? 0,
      capacityMax: (capacity?['max'] as num?)?.toInt() ?? 0,
      interestTag: data['interestTag'] as String?,
      venueName: location?['venueNameSnapshot'] as String?,
    );
  }

  /// The document id.
  final String id;

  /// The hosting user's uid.
  final String hostId;

  /// The Table's title.
  final String title;

  /// Lifecycle status.
  final TableStatus status;

  /// When the Table starts.
  final DateTime startTime;

  /// `capacity.confirmedCount` — how many seats are confirmed.
  final int confirmedCount;

  /// `capacity.max`.
  final int capacityMax;

  /// The single interest tag, if set.
  final String? interestTag;

  /// `location.venueNameSnapshot`, if a venue is chosen.
  final String? venueName;
}

/// One row of the signed-in user's own RSVPs, from the `rsvps`
/// collection-group query (`docs/DATABASE.md` §5's collectionGroup index).
class MyRsvp {
  /// Creates a row.
  const MyRsvp({
    required this.tableId,
    required this.status,
    required this.createdAt,
  });

  /// The parent Table's document id.
  final String tableId;

  /// This RSVP's status.
  final RsvpStatus status;

  /// When the RSVP was created.
  final DateTime createdAt;
}

/// Firestore reads for the `tables` collection that Home (Screen 9) needs —
/// `docs/DATABASE.md` §3.2/§3.3/§5. Same `abstract interface class` + real
/// implementation split as every other repository in this codebase (see
/// `PhoneAuthRepository`'s doc comment for the original rationale).
///
/// Read-only by design: every Table/RSVP *mutation* goes through the F4
/// callables (`createTable`, `requestSeat`, ... — `docs/API_SPEC.md`),
/// never a direct Firestore write, matching `firestore.rules`'
/// Functions-only write posture for both collections.
///
/// Added Milestone F6.
abstract interface class TablesRepository {
  /// Tables the user hosts — `tables where hostId == uid`. Order is
  /// unspecified; Home applies `docs/SCREEN_SPECIFICATIONS.md` Screen 9's
  /// client-side sort itself.
  Future<List<TableSummary>> fetchHostedTables(String uid);

  /// The user's own RSVPs across every Table — the collection-group query
  /// `docs/DATABASE.md` §5's `(userId, status, createdAt)` index backs.
  /// Only statuses Home displays are fetched (invited/requested/confirmed/
  /// waitlisted/attended) — declined and no_show Tables don't appear on
  /// Home at all per Screen 9's card list.
  Future<List<MyRsvp>> fetchMyRsvps(String uid);

  /// One Table by id, or `null` if it doesn't exist or this user may not
  /// read it (a permission denial is mapped to `null` rather than thrown:
  /// the caller is resolving Table ids that came from the user's own RSVP
  /// rows, so a denial means the Table was deleted/rescoped since — a
  /// stale row to skip, not an error state to surface).
  Future<TableSummary?> fetchTable(String tableId);
}

/// The real, Firestore-backed [TablesRepository].
class FirestoreTablesRepository implements TablesRepository {
  /// Creates a repository over [firestore], defaulting to the app's real
  /// instance.
  FirestoreTablesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _homeVisibleRsvpStatuses = [
    'invited',
    'requested',
    'confirmed',
    'waitlisted',
    'attended',
  ];

  @override
  Future<List<TableSummary>> fetchHostedTables(String uid) async {
    final snapshot = await _firestore
        .collection('tables')
        .where('hostId', isEqualTo: uid)
        .get();
    return [
      for (final doc in snapshot.docs) TableSummary.fromDoc(doc.id, doc.data()),
    ];
  }

  @override
  Future<List<MyRsvp>> fetchMyRsvps(String uid) async {
    // Filter shape matches docs/DATABASE.md §5's collection-group index
    // (userId ASC, status ASC, createdAt DESC) exactly — and
    // firestore.rules' collection-group rsvps rule requires the
    // userId == uid filter for the query to be allowed at all.
    final snapshot = await _firestore
        .collectionGroup('rsvps')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: _homeVisibleRsvpStatuses)
        .orderBy('createdAt', descending: true)
        .get();
    return [
      for (final doc in snapshot.docs)
        MyRsvp(
          // rsvps docs live at tables/{tableId}/rsvps/{uid} — the
          // grandparent document is the Table.
          tableId: doc.reference.parent.parent!.id,
          status: RsvpStatus.fromWire(doc.data()['status'] as String?),
          createdAt: (doc.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime(1970),
        ),
    ];
  }

  @override
  Future<TableSummary?> fetchTable(String tableId) async {
    try {
      final doc = await _firestore.doc('tables/$tableId').get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return TableSummary.fromDoc(doc.id, data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
TablesRepository tablesRepository(Ref ref) => FirestoreTablesRepository();
