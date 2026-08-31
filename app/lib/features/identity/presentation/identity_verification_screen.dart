import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/data/identity_verification_repository.dart';
import 'package:tablecrew/features/identity/application/identity_verification_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

/// Screen 8 — Identity Verification (Tier 2, ID + selfie, manually
/// reviewed), per docs/SCREEN_SPECIFICATIONS.md and ADR 0007.
///
/// Two claims this screen's copy is **not permitted to make**, both
/// corrected in docs/SECURITY.md when manual review replaced the vendor
/// flow:
///
///  1. It is not a criminal background check (legally material, see
///     docs/LEGAL.md §5) — that was already true under the vendor design.
///  2. It is **not a liveness check**. A person comparing a selfie to an
///     ID does not establish physical presence; a printed photo or a
///     replayed video defeats it. Wording like "confirms you're really
///     here" would be false during Phase 0.
///
/// Every string below was written against those two constraints. Please
/// re-read them before editing the copy.
///
/// Added Milestone F7.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  /// Creates the identity-verification screen.
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  @override
  void initState() {
    super.initState();
    // Recover an open review left by a previous app run before showing a
    // capture flow the user cannot get past — see the controller's
    // restorePendingSubmission doc comment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        unawaited(
          ref
              .read(identityVerificationControllerProvider.notifier)
              .restorePendingSubmission(uid),
        );
      }
    });
  }

  Future<void> _capture({required bool isSelfie}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          isSelfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final contentType = picked.mimeType ?? 'image/jpeg';
    final controller =
        ref.read(identityVerificationControllerProvider.notifier);
    if (isSelfie) {
      controller.setSelfie(bytes, contentType);
    } else {
      controller.setIdDocument(bytes, contentType);
    }
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref
        .read(identityVerificationControllerProvider.notifier)
        .submit(uid);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityVerificationControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
      body: SafeArea(
        child: switch (state.status) {
          IdentitySubmitStatus.restoring => const _RestoringView(),
          IdentitySubmitStatus.submitted =>
            _ReviewStatusView(submissionId: state.submissionId!),
          _ => _CaptureView(
              state: state,
              theme: theme,
              onCaptureId: () => _capture(isSelfie: false),
              onCaptureSelfie: () => _capture(isSelfie: true),
              onSubmit: _submit,
            ),
        },
      ),
    );
  }
}

class _RestoringView extends StatelessWidget {
  const _RestoringView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(SpacingTokens.lg),
      // Skeleton pulse, never a spinner (docs/DESIGN_SYSTEM.md §8).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonPulse(width: double.infinity, height: 28),
          SizedBox(height: SpacingTokens.md),
          SkeletonPulse(width: double.infinity, height: 120),
        ],
      ),
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView({
    required this.state,
    required this.theme,
    required this.onCaptureId,
    required this.onCaptureSelfie,
    required this.onSubmit,
  });

  final IdentityVerificationState state;
  final ThemeData theme;
  final VoidCallback onCaptureId;
  final VoidCallback onCaptureSelfie;
  final Future<void> Function() onSubmit;

  bool get _busy =>
      state.status == IdentitySubmitStatus.uploading ||
      state.status == IdentitySubmitStatus.submitting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      children: [
        Text("Let's verify it's really you",
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'A real person on our team checks your ID against your selfie. '
          'This confirms your identity so Discover stays real — it is not '
          'a background check.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          "Reviews usually take a day or so. We'll let you know here as "
          'soon as it is done — you can close the app in the meantime.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: SpacingTokens.lg),
        _DocumentTypeField(state: state),
        const SizedBox(height: SpacingTokens.lg),
        _CaptureCard(
          label: 'Government ID',
          hint: 'A clear photo of the whole document.',
          bytes: state.idDocumentBytes,
          onCapture: _busy ? null : onCaptureId,
        ),
        const SizedBox(height: SpacingTokens.md),
        _CaptureCard(
          label: 'Selfie holding your ID',
          // Deliberately not called a liveness check anywhere — it raises
          // the cost of submitting someone else's ID, nothing more.
          hint: 'Hold the same ID next to your face.',
          bytes: state.selfieBytes,
          onCapture: _busy ? null : onCaptureSelfie,
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text(
          'Your ID is visible only to the person reviewing it, and we '
          'delete both photos as soon as your review is done.',
          style: theme.textTheme.bodySmall,
        ),
        if (state.status == IdentitySubmitStatus.failed) ...[
          const SizedBox(height: SpacingTokens.md),
          _ErrorBanner(state: state, theme: theme),
        ],
        const SizedBox(height: SpacingTokens.lg),
        FilledButton(
          onPressed: state.canSubmit ? () => unawaited(onSubmit()) : null,
          child: Text(_busy ? 'Sending…' : 'Submit for review'),
        ),
        const SizedBox(height: SpacingTokens.md),
        const ExpansionTile(
          title: Text('Why do we ask?'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: SpacingTokens.md),
              child: Text(
                'Discover introduces you to people you have never met, in '
                'person. Checking a government ID first means everyone at '
                'the table has been confirmed to be a real, specific '
                'person. It is not a criminal background check, and we '
                'never show your ID or your legal name to anyone else.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentTypeField extends ConsumerWidget {
  const _DocumentTypeField({required this.state});

  final IdentityVerificationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<IdentityDocumentType>(
      initialValue: state.documentType,
      decoration: const InputDecoration(labelText: 'Which document?'),
      items: [
        for (final type in IdentityDocumentType.values)
          DropdownMenuItem<IdentityDocumentType>(
            value: type,
            child: Text(type.label),
          ),
      ],
      onChanged: (type) {
        if (type != null) {
          ref
              .read(identityVerificationControllerProvider.notifier)
              .setDocumentType(type);
        }
      },
    );
  }
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.label,
    required this.hint,
    required this.bytes,
    required this.onCapture,
  });

  final String label;
  final String hint;
  final Uint8List? bytes;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final captured = bytes != null;
    return Semantics(
      // The capture state is announced, not implied by a thumbnail —
      // docs/SCREEN_SPECIFICATIONS.md Screen 8's Accessibility Notes.
      label: '$label, ${captured ? 'captured' : 'not yet captured'}',
      button: true,
      child: Card(
        child: ListTile(
          leading: captured
              ? ClipRRect(
                  borderRadius:
                      BorderRadius.circular(SpacingTokens.radiusControl),
                  child: Image.memory(bytes!,
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : const Icon(Icons.photo_camera_outlined),
          title: Text(label),
          subtitle: Text(captured ? 'Captured — tap to retake' : hint),
          trailing: const Icon(Icons.chevron_right),
          onTap: onCapture,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.state, required this.theme});

  final IdentityVerificationState state;
  final ThemeData theme;

  String get _message {
    switch (state.errorCode) {
      case 'RATE_LIMITED':
        return 'You have reached the limit of verification attempts for '
            'now. Please try again later, or contact us if you are stuck.';
      case 'ALREADY_VERIFIED':
        return 'Your identity is already verified.';
      case 'UPLOAD_NOT_FOUND':
        return "Your photos didn't finish uploading. Please retake them "
            'and try again.';
      default:
        return state.errorMessage ??
            'Something went wrong sending your documents. Please try '
                'again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(SpacingTokens.radiusControl),
      ),
      child: Text(
        _message,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

class _ReviewStatusView extends ConsumerWidget {
  const _ReviewStatusView({required this.submissionId});

  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status =
        ref.watch(identityVerificationStatusProvider(submissionId));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: status.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SkeletonPulse(width: double.infinity, height: 120)],
        ),
        error: (_, __) => Text(
          "We couldn't load your verification status. It is safe to close "
          'this and come back.',
          style: theme.textTheme.bodyMedium,
        ),
        data: (value) => _StatusCard(status: value, theme: theme),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.status, required this.theme});

  final IdentityVerificationStatus status;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A live region: the status changes while the screen is open, and a
    // screen reader should hear it rather than only render it.
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (status) {
          IdentityPendingReview() => [
              Text('Waiting for review', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Someone on our team is looking at your documents. This '
                'usually takes a day or so. You can close the app — we '
                'will keep your place.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SpacingTokens.lg),
              const SkeletonPulse(width: double.infinity, height: 80),
            ],
          IdentityApproved() => [
              Text("You're verified", style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Your identity is confirmed. Open Tables and Discover are '
                'available to you now.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SpacingTokens.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          IdentityRejected(reason: final reason) => [
              Text("We couldn't verify you this time",
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.sm),
              // The reviewer's own words. Under manual review the usual
              // cause is fixable (an unreadable photo), so this is shown
              // verbatim rather than replaced with a generic failure —
              // reviewIdentityVerification refuses a reasonless rejection
              // precisely so there is always something to show here.
              Text(reason, style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpacingTokens.lg),
              FilledButton(
                onPressed: () => ref
                    .read(identityVerificationControllerProvider.notifier)
                    .reset(),
                child: const Text('Try again'),
              ),
            ],
          IdentityHeldForReview() => [
              Text('Taking a closer look', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.sm),
              // Deliberately says nothing about a report. Telling the
              // subject of an open report that one exists, and when, would
              // leak exactly what docs/SECURITY.md's silent-reporting rule
              // protects.
              Text(
                'Someone on our team is reviewing your account. We will '
                'update you here as soon as we can.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
        },
      ),
    );
  }
}
