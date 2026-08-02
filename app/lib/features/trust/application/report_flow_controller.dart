import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';

part 'report_flow_controller.g.dart';

/// [ReportFlowController]'s lifecycle states.
enum ReportFlowStatus {
  /// Nothing submitted yet.
  idle,

  /// A `reportUser`/`reportTable` (and, if the block toggle is checked,
  /// `blockUser`) call is in flight.
  submitting,

  /// The report was filed successfully — Screen 27's confirmation state.
  succeeded,

  /// A real, non-connectivity failure — see [ReportFlowState.errorMessage].
  failed,
}

/// [ReportFlowController]'s state.
class ReportFlowState {
  /// Creates a state, defaulting to idle.
  const ReportFlowState({
    this.status = ReportFlowStatus.idle,
    this.errorCode,
    this.errorMessage,
  });

  /// The current status.
  final ReportFlowStatus status;

  /// The app-specific error code when [status] is
  /// [ReportFlowStatus.failed] (e.g. `already-exists` for a duplicate open
  /// report).
  final String? errorCode;

  /// A human-readable message when [status] is [ReportFlowStatus.failed].
  final String? errorMessage;
}

/// Drives Screen 27 (Report Flow)'s submission — `reportUser`/
/// `reportTable`, plus an optional `blockUser` call if the inline "Also
/// block this person" toggle was checked, per docs/SCREEN_SPECIFICATIONS.md
/// Screen 27's Exit Points.
///
/// Family-keyed by [targetRef], a composite string (`"user:$uid"` or
/// `"table:$tableId"`) rather than a two-argument family — this mirrors
/// the mutationId string-composition convention already used elsewhere in
/// this codebase (e.g. `TableDetailActionController.confirmAttendee`'s
/// `'confirmAttendee:$tableId:$targetUserId'`) instead of introducing this
/// codebase's first multi-argument Riverpod family.
///
/// Plain `@riverpod` (autoDispose), unlike `CreateTableController`/
/// `TableDetailActionController`: Screen 27's Offline Behavior is "blocked
/// entirely offline rather than queued" (a report must reach a live
/// connection immediately, not sit in an offline queue that could delay or
/// lose a safety-critical submission) — there's no background
/// retry-on-reconnect to keep alive across navigation, so this controller
/// can reset naturally once the screen is popped.
///
/// Added Milestone F6 (Trust & Safety client chunk).
@riverpod
class ReportFlowController extends _$ReportFlowController {
  @override
  ReportFlowState build(String targetRef) => const ReportFlowState();

  /// Submits the report. The target type/id are parsed from [targetRef]
  /// rather than re-passed by the caller, so the widget can't drift from
  /// the family key it's watching.
  Future<void> submit({
    required ReportReasonCode reasonCode,
    required bool alsoBlock,
    String? details,
  }) async {
    state = const ReportFlowState(status: ReportFlowStatus.submitting);

    final connectivity = ref.read(connectivityRepositoryProvider);
    if (await connectivity.isOffline()) {
      state = const ReportFlowState(
        status: ReportFlowStatus.failed,
        errorMessage: "You're offline. Reports need a live connection to "
            "reach our Trust & Safety team — please try again once you're "
            'connected.',
      );
      return;
    }

    final separatorIndex = targetRef.indexOf(':');
    final targetType = targetRef.substring(0, separatorIndex);
    final targetId = targetRef.substring(separatorIndex + 1);
    final trust = ref.read(trustRepositoryProvider);

    try {
      if (targetType == 'table') {
        await trust.reportTable(
          targetTableId: targetId,
          reasonCode: reasonCode,
          details: details,
        );
      } else {
        await trust.reportUser(
          targetUserId: targetId,
          reasonCode: reasonCode,
          details: details,
        );
        // The block toggle only applies to a user target — Screen 27
        // never shows it when reporting a Table (there's no "block a
        // Table" concept), so `alsoBlock` can only be true here.
        if (alsoBlock) {
          await trust.blockUser(targetUserId: targetId);
        }
      }
      state = const ReportFlowState(status: ReportFlowStatus.succeeded);
    } on TrustCallableException catch (e) {
      state = ReportFlowState(
        status: ReportFlowStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
    }
  }
}
