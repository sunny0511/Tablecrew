import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'table_mutations_repository.g.dart';

/// Thrown by [TableMutationsRepository] when a Tables callable rejects with
/// a known app-specific error code (docs/API_SPEC.md §3.1's `HttpsError`
/// details, e.g. `TRUST_STANDING_RESTRICTED`) — the same shape
/// `OnboardingCallableException` (`user_profile_repository.dart`)
/// established for the users callables.
class TableCallableException implements Exception {
  /// Creates an exception carrying the app-specific [code] and
  /// human-readable [message].
  const TableCallableException({required this.code, required this.message});

  /// The app-specific code (e.g. `TRUST_STANDING_RESTRICTED`), or the
  /// generic Firebase error code when no details were attached.
  final String code;

  /// A human-readable message.
  final String message;

  @override
  String toString() => 'TableCallableException($code): $message';
}

/// A venue as selected in Venue Picker (Screen 11) and carried through
/// Create Table's draft — provider-matched venues have coordinates,
/// manually-entered ones don't ([latitude]/[longitude] null, the
/// "unverified-location" state docs/API_SPEC.md §3.1's F6 correction
/// represents as `geopoint: null`).
class VenueSelection {
  /// Creates a selection.
  const VenueSelection({
    required this.name,
    required this.address,
    this.venueId,
    this.latitude,
    this.longitude,
  });

  /// Deserializes from [toJson]'s shape (draft persistence).
  factory VenueSelection.fromJson(Map<String, dynamic> json) {
    return VenueSelection(
      name: json['name'] as String,
      address: json['address'] as String,
      venueId: json['venueId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// The venue's display name.
  final String name;

  /// The venue's address line.
  final String address;

  /// The partner-venue document id, if any (`venues/{venueId}`).
  final String? venueId;

  /// Latitude, if the venue came from a provider with coordinates.
  final double? latitude;

  /// Longitude, if the venue came from a provider with coordinates.
  final double? longitude;

  /// Serializes for draft persistence.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'venueId': venueId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// The result of a successful `createTable` call (docs/API_SPEC.md §3.1).
class CreateTableResult {
  /// Creates a result.
  const CreateTableResult({required this.tableId, required this.status});

  /// The new Table's document id.
  final String tableId;

  /// The new Table's lifecycle status (always `"proposed"`).
  final String status;
}

/// The result of a successful `requestSeat` call (docs/API_SPEC.md §3.1).
class RequestSeatResult {
  /// Creates a result.
  const RequestSeatResult(this.rsvpStatus);

  /// The RSVP status the server assigned — for an F6-scope Closed Table,
  /// always `"requested"` (the server checks `visibility == 'closed'`
  /// before capacity at all, per `functions/src/tables/index.ts`'s
  /// `requestSeat`), pending the host's `confirmAttendee`.
  final String rsvpStatus;
}

/// The Tables *mutation* surface — the F4 callables, starting with
/// `createTable` (docs/API_SPEC.md §3.1). Split from the read-only
/// `TablesRepository` (`tables_repository.dart`) deliberately: reads go
/// straight to Firestore under rules, mutations only ever go through
/// callables, and keeping the two surfaces in separate classes makes that
/// boundary structural rather than a comment. Same interface/impl split as
/// every repository in this codebase.
///
/// Added Milestone F6.
abstract interface class TableMutationsRepository {
  /// docs/API_SPEC.md §3.1 `createTable`. [idempotencyKey] comes from
  /// `OfflineMutationQueue.run` (docs/API_SPEC.md §2) — never minted here.
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
  });

  /// docs/API_SPEC.md §3.1 `requestSeat` — Table Detail (Screen 13)'s
  /// non-attendee primary action. [idempotencyKey] comes from
  /// `OfflineMutationQueue.run`, same as [createTable].
  Future<RequestSeatResult> requestSeat({
    required String tableId,
    required String idempotencyKey,
  });

  /// docs/API_SPEC.md §3.1 `cancelRsvp` — Screen 13's attendee "Cancel
  /// RSVP" primary action. Idempotent by construction server-side (a
  /// retry after the RSVP is already gone is a no-op success, not an
  /// error) as well as by [idempotencyKey].
  Future<void> cancelRsvp({
    required String tableId,
    required String idempotencyKey,
  });

  /// docs/API_SPEC.md §3.1 `confirmAttendee` — the host's action on a
  /// Requested attendee row, since every `requestSeat` on an F6-scope
  /// Closed Table lands as `"requested"`, never auto-confirmed.
  Future<void> confirmAttendee({
    required String tableId,
    required String targetUserId,
    required String idempotencyKey,
  });

  /// docs/API_SPEC.md §3.1 `cancelTable` — the host's overflow-menu
  /// action. No `idempotencyKey` in this callable's request contract at
  /// all (unlike the others above): it's idempotent by construction via
  /// the Table's own `status` field (a repeat cancel of an already-
  /// cancelled Table is a no-op success), the same reasoning
  /// `AccountSetupController`'s doc comment gives for
  /// `completeAccountSetup` needing no key either.
  Future<void> cancelTable({required String tableId, String? reason});
}

/// The real, Cloud Functions-backed [TableMutationsRepository].
class FirebaseTableMutationsRepository implements TableMutationsRepository {
  /// Creates a repository over [functions], defaulting to the app's real
  /// instance.
  FirebaseTableMutationsRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

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
    final callable = _functions.httpsCallable('createTable');
    try {
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'title': title,
          'visibility': visibility,
          'location': <String, dynamic>{
            'geopoint': venue.latitude == null || venue.longitude == null
                ? null
                : <String, dynamic>{
                    'lat': venue.latitude,
                    'lng': venue.longitude,
                  },
            if (venue.venueId != null) 'venueId': venue.venueId,
            'venueName': venue.name,
            'address': venue.address,
          },
          'startTime': startTime.toUtc().toIso8601String(),
          'capacity': <String, dynamic>{
            'min': capacityMin,
            'max': capacityMax,
          },
          if (interestTag != null) 'interestTag': interestTag,
          if (description != null) 'description': description,
          if (crewId != null) 'crewId': crewId,
          'idempotencyKey': idempotencyKey,
        },
      );
      final data = result.data;
      return CreateTableResult(
        tableId: data['tableId'] as String,
        status: data['status'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<RequestSeatResult> requestSeat({
    required String tableId,
    required String idempotencyKey,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('requestSeat')
          .call<Map<String, dynamic>>(<String, dynamic>{
        'tableId': tableId,
        'idempotencyKey': idempotencyKey,
      });
      return RequestSeatResult(result.data['rsvpStatus'] as String);
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> cancelRsvp({
    required String tableId,
    required String idempotencyKey,
  }) async {
    try {
      await _functions.httpsCallable('cancelRsvp').call<Map<String, dynamic>>(
        <String, dynamic>{'tableId': tableId, 'idempotencyKey': idempotencyKey},
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> confirmAttendee({
    required String tableId,
    required String targetUserId,
    required String idempotencyKey,
  }) async {
    try {
      await _functions
          .httpsCallable('confirmAttendee')
          .call<Map<String, dynamic>>(<String, dynamic>{
        'tableId': tableId,
        'targetUserId': targetUserId,
        'idempotencyKey': idempotencyKey,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> cancelTable({required String tableId, String? reason}) async {
    try {
      await _functions.httpsCallable('cancelTable').call<Map<String, dynamic>>(
        <String, dynamic>{
          'tableId': tableId,
          if (reason != null) 'reason': reason,
        },
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  TableCallableException _mapException(FirebaseFunctionsException e) {
    final details = e.details;
    if (details is Map && details['code'] is String) {
      return TableCallableException(
        code: details['code'] as String,
        message: (details['message'] as String?) ?? e.message ?? e.code,
      );
    }
    return TableCallableException(code: e.code, message: e.message ?? e.code);
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
TableMutationsRepository tableMutationsRepository(Ref ref) =>
    FirebaseTableMutationsRepository();
