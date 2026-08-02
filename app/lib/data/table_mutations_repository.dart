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

/// The Tables *mutation* surface — the F4 callables, starting with
/// `createTable` (docs/API_SPEC.md §3.1). Split from the read-only
/// `TablesRepository` (`tables_repository.dart`) deliberately: reads go
/// straight to Firestore under rules, mutations only ever go through
/// callables, and keeping the two surfaces in separate classes makes that
/// boundary structural rather than a comment. Same interface/impl split as
/// every repository in this codebase.
///
/// Added Milestone F6. `requestSeat`/`cancelRsvp`/... join here with Table
/// Detail (Screen 13)'s chunk — one member today, but this stays a
/// repository interface for the same reason `CrewsRepository`
/// (`crews_repository.dart`) does: more reads land here soon, and the
/// interface/impl split is what lets tests fake it without a real
/// Cloud Functions call.
// ignore: one_member_abstracts
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
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw TableCallableException(
          code: details['code'] as String,
          message: (details['message'] as String?) ?? e.message ?? e.code,
        );
      }
      throw TableCallableException(
        code: e.code,
        message: e.message ?? e.code,
      );
    }
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
TableMutationsRepository tableMutationsRepository(Ref ref) =>
    FirebaseTableMutationsRepository();
