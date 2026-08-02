import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trust_repository.g.dart';

/// Thrown by [TrustRepository] when a Trust & Safety callable rejects with
/// a known error — same shape `TableCallableException`
/// (`table_mutations_repository.dart`) established: a `details.code` when
/// the server attached one (e.g. `RATE_LIMITED`), otherwise the raw
/// Firebase Functions error code (e.g. `already-exists` for a duplicate
/// open report, `invalid-argument` for a missing reason).
class TrustCallableException implements Exception {
  /// Creates an exception carrying the app-specific [code] and
  /// human-readable [message].
  const TrustCallableException({required this.code, required this.message});

  /// The app-specific code, or the generic Firebase error code when no
  /// details were attached.
  final String code;

  /// A human-readable message.
  final String message;

  @override
  String toString() => 'TrustCallableException($code): $message';
}

/// docs/DATABASE.md §3.6's `reasonCode` enum, minus the system-only
/// `flagged_media` value a client is never allowed to submit (see
/// `functions/src/trust/validation.ts`'s `CLIENT_REPORT_REASON_CODES` —
/// this list matches that one exactly). Screen 27's UI presents six
/// options, but the API's enum has only these six slots too — see
/// [ReportReasonCode.inappropriateContent]'s own doc comment for the one
/// real mapping decision that isn't a 1:1 label-to-code match.
enum ReportReasonCode {
  /// "Harassment."
  harassment('harassment', 'Harassment'),

  /// docs/SCREEN_SPECIFICATIONS.md Screen 27 lists "Inappropriate content/
  /// behavior" as its own radio option, but `docs/DATABASE.md` §3.6's
  /// `reasonCode` enum has no dedicated code for it — only six slots exist
  /// total, and this isn't one of the other five. Mapped to `other` rather
  /// than invented as a seventh backend value: `other`'s catch-all
  /// semantics already cover it, and the UI label is what a Trust & Safety
  /// reviewer actually reads first, not the wire code. Disclosed here
  /// rather than silently assumed.
  inappropriateContent('other', 'Inappropriate content or behavior'),

  /// "Safety concern."
  safetyConcern('safety_concern', 'Safety concern'),

  /// "No-show."
  noShow('no_show', 'No-show'),

  /// "Fake profile/spam."
  fakeProfile('fake_profile', 'Fake profile or spam'),

  /// "This happened outside the app" — Screen 27's visually/semantically
  /// separated off-platform option, mapped to the distinct
  /// `off_platform_stalking` code that gets expedited review server-side.
  offPlatform('off_platform_stalking', 'This happened outside the app');

  const ReportReasonCode(this.wireValue, this.label);

  /// The value sent as `reasonCode` in the request body.
  final String wireValue;

  /// Screen 27's radio-button label.
  final String label;
}

/// The Trust & Safety mutation surface (docs/API_SPEC.md §3.4):
/// `reportUser`/`reportTable`/`blockUser`. `triggerDuressSignal` and
/// `createLocationShare`/`revokeLocationShare` aren't exposed here yet —
/// the former has no client screen until the Live Table Screen (Milestone
/// F8), the latter two are still backend-deferred (see
/// `functions/src/trust/index.ts`'s header).
///
/// Added Milestone F6 (Trust & Safety client chunk).
abstract interface class TrustRepository {
  /// docs/API_SPEC.md §3.4 `reportUser`. [details] is required by the
  /// server when [reasonCode] is [ReportReasonCode.offPlatform] — this
  /// repository doesn't re-validate that client-side; it's
  /// `ReportFlowController`'s job (mirroring how `CreateTableController`
  /// leaves field validation to the widget/server, not the repository).
  Future<String> reportUser({
    required String targetUserId,
    required ReportReasonCode reasonCode,
    String? details,
  });

  /// docs/API_SPEC.md §3.4 `reportTable`.
  Future<String> reportTable({
    required String targetTableId,
    required ReportReasonCode reasonCode,
    String? details,
  });

  /// docs/API_SPEC.md §3.4 `blockUser` — idempotent server-side
  /// (`arrayUnion`), so a repeat call for an already-blocked uid is a
  /// no-op success, not an error.
  Future<void> blockUser({required String targetUserId});
}

/// The real, Cloud Functions-backed [TrustRepository].
class FirebaseTrustRepository implements TrustRepository {
  /// Creates a repository over [functions], defaulting to the app's real
  /// instance.
  FirebaseTrustRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<String> reportUser({
    required String targetUserId,
    required ReportReasonCode reasonCode,
    String? details,
  }) {
    return _report(
      callableName: 'reportUser',
      targetType: 'user',
      targetId: targetUserId,
      reasonCode: reasonCode,
      details: details,
    );
  }

  @override
  Future<String> reportTable({
    required String targetTableId,
    required ReportReasonCode reasonCode,
    String? details,
  }) {
    return _report(
      callableName: 'reportTable',
      targetType: 'table',
      targetId: targetTableId,
      reasonCode: reasonCode,
      details: details,
    );
  }

  Future<String> _report({
    required String callableName,
    required String targetType,
    required String targetId,
    required ReportReasonCode reasonCode,
    String? details,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(callableName)
          .call<Map<String, dynamic>>(<String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'reasonCode': reasonCode.wireValue,
        if (details != null) 'details': details,
      });
      return result.data['reportId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> blockUser({required String targetUserId}) async {
    try {
      await _functions.httpsCallable('blockUser').call<Map<String, dynamic>>(
        <String, dynamic>{'targetUserId': targetUserId},
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    }
  }

  TrustCallableException _mapException(FirebaseFunctionsException e) {
    final details = e.details;
    if (details is Map && details['code'] is String) {
      return TrustCallableException(
        code: details['code'] as String,
        message: (details['message'] as String?) ?? e.message ?? e.code,
      );
    }
    return TrustCallableException(code: e.code, message: e.message ?? e.code);
  }
}

/// Riverpod provider (docs/ENGINEERING_GUIDELINES.md: "Repositories ...
/// exposed as providers so they're trivially overridable in tests").
@riverpod
TrustRepository trustRepository(Ref ref) => FirebaseTrustRepository();
