import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/features/trust/application/block_confirmation_controller.dart';

/// Screen 28 (Block Confirmation), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// **Presentation note, disclosed:** the spec calls this a "Modal/sheet."
/// This app's route table (`core/routing/app_router.dart`) has no
/// dialog/bottom-sheet route type wired up anywhere yet — every screen so
/// far is a full GoRoute page (including this route's own pre-existing
/// stub) — so this ships as a routed page styled to read as a centered
/// confirmation card, the same simplification, not a functional gap:
/// nothing about the spec's content or exit-point behavior depends on it
/// being a literal bottom sheet.
///
/// Reachable from Table Detail's attendee-row overflow menu (same entry
/// point `report_flow_screen.dart` documents), added in this same chunk.
///
/// Added Milestone F6 (Trust & Safety client chunk).
class BlockConfirmationScreen extends ConsumerWidget {
  /// Creates the Block Confirmation screen for [targetUserId].
  const BlockConfirmationScreen({
    required this.targetUserId,
    required this.targetDisplayName,
    this.sharesCrew = false,
    super.key,
  });

  /// The uid to block.
  final String targetUserId;

  /// Shown in the headline ("Block {name}?").
  final String targetDisplayName;

  /// Whether the reporter and target currently share a Crew — Table
  /// Detail passes `true` when the Table being viewed is Crew-scoped
  /// (`table.crewId != null`), the one signal this milestone's entry
  /// point actually has available; Screen 28's own inline sentence about
  /// shared-Crew messaging is only shown when this is `true`.
  final bool sharesCrew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(blockConfirmationControllerProvider(targetUserId));

    ref.listen(blockConfirmationControllerProvider(targetUserId), (
      previous,
      next,
    ) {
      if (next.status == BlockConfirmationStatus.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Blocked. They won't be notified.")),
        );
        Navigator.of(context).pop(true);
      }
    });

    final blocking = state.status == BlockConfirmationStatus.blocking;

    return Scaffold(
      appBar: AppBar(title: const Text('Block')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TCSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Block $targetDisplayName?',
                  style:
                      TCTextStyles.displayMd.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: TCSpacing.md),
                Text(
                  'They will not be told. They will no longer appear in '
                  "your Discover results, and they can't request to join "
                  'your Tables again.',
                  style: TCTextStyles.bodyMd.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (sharesCrew) ...[
                  const SizedBox(height: TCSpacing.sm),
                  Text(
                    "If you share a Crew, that membership isn't affected — "
                    "but neither of you will see the other's messages in "
                    "that Crew's chat from now on.",
                    style: TCTextStyles.bodyMd.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (state.status == BlockConfirmationStatus.failed) ...[
                  const SizedBox(height: TCSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.errorMessage ?? 'Something went wrong.',
                      style: TCTextStyles.bodyMd.copyWith(color: colors.error),
                    ),
                  ),
                ],
                const SizedBox(height: TCSpacing.lg),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: blocking ? null : () => _submit(context, ref),
                  child: Text(blocking ? 'Blocking…' : 'Block'),
                ),
                const SizedBox(height: TCSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) {
    return ref
        .read(blockConfirmationControllerProvider(targetUserId).notifier)
        .submit();
  }
}
