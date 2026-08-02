import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';

/// Screen 4's hard-stop under-18 destination
/// (`docs/SCREEN_SPECIFICATIONS.md` Screen 4's Exit Points: "A hard-stop
/// 'You must be 18+' screen with no bypass ..., offering only account
/// deletion / sign-out"). No back navigation, no way to re-enter a
/// different date of birth from here — matching "no bypass" — a user who
/// mistyped their real birthday has to restart the whole phone-verify
/// flow from scratch via one of this screen's two exits.
///
/// **Disclosed open item, carried from the spec's own Future
/// Enhancements note:** copy wording and data-retention handling for the
/// deletion path haven't had legal/Trust & Safety sign-off yet. The
/// button below performs a real Firebase Auth user deletion (not a
/// placeholder), but its exact label/copy should be revisited once that
/// sign-off happens.
///
/// Added Milestone F5.
class AgeIneligibleScreen extends ConsumerStatefulWidget {
  /// Creates the age-ineligible hard-stop screen.
  const AgeIneligibleScreen({super.key});

  @override
  ConsumerState<AgeIneligibleScreen> createState() =>
      _AgeIneligibleScreenState();
}

class _AgeIneligibleScreenState extends ConsumerState<AgeIneligibleScreen> {
  bool _isProcessing = false;

  Future<void> _signOut() async {
    setState(() => _isProcessing = true);
    await ref.read(phoneAuthRepositoryProvider).signOut();
    if (!mounted) return;
    context.goNamed('phone-entry');
  }

  Future<void> _deleteAccount() async {
    setState(() => _isProcessing = true);
    await ref.read(phoneAuthRepositoryProvider).deleteAccount();
    if (!mounted) return;
    context.goNamed('phone-entry');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accessibility Notes: "plain, non-alarming Fraunces/Inter
              // copy ... rather than red error styling, since this is a
              // policy boundary, not a user error" — no colors.error use
              // anywhere on this screen, by design.
              Text(
                'TableCrew is for adults 18 and up',
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.md),
              Text(
                "Based on the birthday you entered, we can't create an "
                'account for you right now.',
                style: TCTextStyles.bodyLg.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.xl),
              OutlinedButton(
                onPressed: _isProcessing ? null : _signOut,
                child: const Text('Sign out'),
              ),
              const SizedBox(height: TCSpacing.sm),
              TextButton(
                onPressed: _isProcessing ? null : _deleteAccount,
                child: const Text('Delete my account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
