import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';

part 'block_confirmation_controller.g.dart';

/// [BlockConfirmationController]'s lifecycle states.
enum BlockConfirmationStatus {
  /// Nothing submitted yet.
  idle,

  /// A `blockUser` call is in flight.
  blocking,

  /// The block succeeded.
  succeeded,

  /// A real, non-connectivity failure.
  failed,
}

/// [BlockConfirmationController]'s state.
class BlockConfirmationState {
  /// Creates a state, defaulting to idle.
  const BlockConfirmationState({
    this.status = BlockConfirmationStatus.idle,
    this.errorMessage,
  });

  /// The current status.
  final BlockConfirmationStatus status;

  /// A human-readable message when [status] is
  /// [BlockConfirmationStatus.failed].
  final String? errorMessage;
}

/// Drives Screen 28 (Block Confirmation)'s single action — `blockUser` —
/// family-keyed by the target's uid so two different targets never share
/// state.
///
/// Plain `@riverpod` (autoDispose), same reasoning as
/// [ReportFlowController]: Screen 28's Offline Behavior blocks the action
/// entirely rather than queuing it ("This can't be done offline"), since a
/// block must propagate immediately to Discover-matching and Table-join
/// eligibility — there's nothing to keep alive across navigation.
///
/// Added Milestone F6 (Trust & Safety client chunk).
@riverpod
class BlockConfirmationController extends _$BlockConfirmationController {
  @override
  BlockConfirmationState build(String targetUserId) =>
      const BlockConfirmationState();

  /// Confirms the block.
  Future<void> submit() async {
    state =
        const BlockConfirmationState(status: BlockConfirmationStatus.blocking);

    final connectivity = ref.read(connectivityRepositoryProvider);
    if (await connectivity.isOffline()) {
      state = const BlockConfirmationState(
        status: BlockConfirmationStatus.failed,
        errorMessage: "Connect to block this person. This can't be done "
            'offline.',
      );
      return;
    }

    try {
      await ref
          .read(trustRepositoryProvider)
          .blockUser(targetUserId: targetUserId);
      state = const BlockConfirmationState(
        status: BlockConfirmationStatus.succeeded,
      );
    } on TrustCallableException catch (e) {
      state = BlockConfirmationState(
        status: BlockConfirmationStatus.failed,
        errorMessage: e.message,
      );
    }
  }
}
