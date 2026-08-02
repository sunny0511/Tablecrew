import 'package:tablecrew/data/trust_repository.dart';

/// Hand-written fake of [TrustRepository]
/// (`app/lib/data/trust_repository.dart`). Used by `ReportFlowController`/
/// `BlockConfirmationController`'s tests and their screens' widget tests
/// (Milestone F6, Trust & Safety client chunk).
class FakeTrustRepository implements TrustRepository {
  /// What [reportUser]/[reportTable] return on success.
  String reportIdResult = 'report-fake';

  /// If set, [reportUser]/[reportTable] throw this instead.
  Exception? reportError;

  /// Every [reportUser] call's arguments, in order.
  final List<
      ({
        String targetUserId,
        ReportReasonCode reasonCode,
        String? details,
      })> reportUserCalls = [];

  /// Every [reportTable] call's arguments, in order.
  final List<
      ({
        String targetTableId,
        ReportReasonCode reasonCode,
        String? details,
      })> reportTableCalls = [];

  @override
  Future<String> reportUser({
    required String targetUserId,
    required ReportReasonCode reasonCode,
    String? details,
  }) async {
    reportUserCalls.add(
      (targetUserId: targetUserId, reasonCode: reasonCode, details: details),
    );
    final error = reportError;
    if (error != null) throw error;
    return reportIdResult;
  }

  @override
  Future<String> reportTable({
    required String targetTableId,
    required ReportReasonCode reasonCode,
    String? details,
  }) async {
    reportTableCalls.add(
      (
        targetTableId: targetTableId,
        reasonCode: reasonCode,
        details: details,
      ),
    );
    final error = reportError;
    if (error != null) throw error;
    return reportIdResult;
  }

  /// If set, [blockUser] throws this instead of succeeding.
  Exception? blockUserError;

  /// Every [blockUser] call's `targetUserId`, in order.
  final List<String> blockUserCalls = [];

  @override
  Future<void> blockUser({required String targetUserId}) async {
    blockUserCalls.add(targetUserId);
    final error = blockUserError;
    if (error != null) throw error;
  }
}
