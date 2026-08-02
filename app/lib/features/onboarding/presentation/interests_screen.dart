import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/interest_taxonomy.dart';
import 'package:tablecrew/features/onboarding/application/account_setup_controller.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

/// Screen 6 (Interest Selection), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// The chip grid renders [kInterestTaxonomy] — see that constant's doc
/// comment for the disclosed taxonomy-enforcement gap this screen builds
/// against anyway. This is also the screen that fires the combined
/// `completeAccountSetup` call (via [AccountSetupController]) for the
/// whole onboarding flow, per Screen 6's own API Calls note.
///
/// Added Milestone F5.
class InterestsScreen extends ConsumerStatefulWidget {
  /// Creates the Interest Selection screen.
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Resumes a prior in-session selection (e.g. the user backed up from
    // Notification Priming) rather than always starting empty.
    _selected = {
      ...ref.read(onboardingProfileDraftControllerProvider).interestTags,
    };
  }

  Future<void> _continue() async {
    if (_selected.length < kMinInterestTags) return;

    ref
        .read(onboardingProfileDraftControllerProvider.notifier)
        .setInterestTags(_selected.toList());

    final proceed = await ref
        .read(accountSetupControllerProvider.notifier)
        .submit();
    if (!mounted) return;

    if (proceed) {
      context.goNamed('notification-priming');
      return;
    }

    final errorCode = ref.read(accountSetupControllerProvider).errorCode;
    if (errorCode == 'PHOTO_NOT_APPROVED') {
      context.goNamed('profile-setup');
    } else if (errorCode == 'UNDER_MINIMUM_AGE') {
      context.goNamed('age-ineligible');
    }
    // Any other failure stays on this screen — the inline notice built
    // from accountSetupControllerProvider's watched state (below) already
    // surfaces it, and "Continue" is enabled again for a retry.
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final setupState = ref.watch(accountSetupControllerProvider);
    final isSubmitting =
        setupState.status == AccountSetupStatus.submitting ||
        setupState.status == AccountSetupStatus.queued;
    final canContinue = _selected.length >= kMinInterestTags && !isSubmitting;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What kind of Tables are you into?',
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                'Pick at least 3 — you can change these anytime.',
                style: TCTextStyles.bodyMd.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              Wrap(
                spacing: TCSpacing.sm,
                runSpacing: TCSpacing.sm,
                children: [
                  for (final option in kInterestTaxonomy)
                    FilterChip(
                      label: Text(option.label),
                      selected: _selected.contains(option.tag),
                      selectedColor: TCColors.primary100,
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selected.add(option.tag);
                          } else {
                            _selected.remove(option.tag);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: TCSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _selected.length >= kMinInterestTags
                      ? '${_selected.length} selected'
                      : 'Pick at least $kMinInterestTags to continue '
                            '(${_selected.length} selected)',
                  style: TCTextStyles.bodyMd.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (setupState.status == AccountSetupStatus.failed &&
                  setupState.errorCode != 'PHOTO_NOT_APPROVED' &&
                  setupState.errorCode != 'UNDER_MINIMUM_AGE') ...[
                const SizedBox(height: TCSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    setupState.errorMessage ??
                        "Couldn't save — check your connection and try "
                            'again.',
                    style: TCTextStyles.bodyMd.copyWith(color: colors.error),
                  ),
                ),
              ],
              const SizedBox(height: TCSpacing.lg),
              if (isSubmitting)
                const Center(child: SkeletonPulse(width: 200, height: 48))
              else
                ElevatedButton(
                  onPressed: canContinue ? _continue : null,
                  child: const Text('Continue'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
