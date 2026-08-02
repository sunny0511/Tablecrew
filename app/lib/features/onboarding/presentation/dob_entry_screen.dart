import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

const _minAgeYears = 18;
const _maxAgeYears = 120;
const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Screen 4 (Date of Birth Entry / Age Gate),
/// `docs/SCREEN_SPECIFICATIONS.md`.
///
/// Uses Flutter's built-in [showDatePicker] rather than a hand-rolled
/// scroll-wheel picker, matching the spec's own Accessibility Notes ("A
/// native date picker is used ... to guarantee correct screen-reader
/// semantics for day/month/year values").
///
/// No dedicated Riverpod controller — unlike Screens 2-3's
/// `OnboardingPhoneFlowController`, this screen's logic is one field and
/// one network call with no retry/lockout state machine to justify a
/// separate controller; plain local [State] plus direct repository calls
/// (the same shape `PhoneEntryScreen`/`OtpScreen` already use for their
/// non-flow-controller concerns like offline detection) is proportionate.
///
/// Added Milestone F5.
class DobEntryScreen extends ConsumerStatefulWidget {
  /// Creates the Date of Birth Entry screen.
  const DobEntryScreen({super.key});

  @override
  ConsumerState<DobEntryScreen> createState() => _DobEntryScreenState();
}

class _DobEntryScreenState extends ConsumerState<DobEntryScreen> {
  DateTime? _dateOfBirth;
  bool _isValidating = false;
  bool _isOffline = false;
  String? _error;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    final connectivity = Connectivity();
    unawaited(_checkInitialConnectivity(connectivity));
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) return;
      setState(() => _isOffline = _isOfflineResult(results));
    });
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  Future<void> _checkInitialConnectivity(Connectivity connectivity) async {
    final result = await connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _isOffline = _isOfflineResult(result));
  }

  bool _isOfflineResult(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final defaultAdultDate = DateTime(
      now.year - _minAgeYears,
      now.month,
      now.day,
    );
    final picked = await showDatePicker(
      context: context,
      // Validation Rules: "not in the future" (lastDate) — [firstDate]'s
      // 120-year bound is a plausibility bound, not a spec'd number.
      initialDate: _dateOfBirth ?? defaultAdultDate,
      firstDate: DateTime(now.year - _maxAgeYears),
      lastDate: now,
      helpText: "When's your birthday?",
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _error = null;
    });
  }

  Future<void> _continue() async {
    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth == null || _isOffline || _isValidating) return;

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final eligible = await ref
          .read(userProfileRepositoryProvider)
          .validateAge(dateOfBirth);
      if (!mounted) return;
      if (!eligible) {
        context.goNamed('age-ineligible');
        return;
      }
      ref
          .read(onboardingProfileDraftControllerProvider.notifier)
          .setDateOfBirth(dateOfBirth);
      context.goNamed('profile-setup');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? "Couldn't verify — try again.");
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  String _formatDate(DateTime date) {
    final month = _monthAbbreviations[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canContinue = _dateOfBirth != null && !_isOffline && !_isValidating;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "When's your birthday?",
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                'This determines eligibility to use TableCrew and is '
                'never shown on your public profile.',
                style: TCTextStyles.bodyMd.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              OutlinedButton(
                onPressed: _isValidating ? null : _pickDate,
                child: Text(
                  _dateOfBirth == null
                      ? 'Select date of birth'
                      : _formatDate(_dateOfBirth!),
                ),
              ),
              const SizedBox(height: TCSpacing.md),
              if (_isOffline)
                _notice(
                  'We need a connection to verify your age.',
                  colors.error,
                )
              else if (_error != null)
                _notice(_error!, colors.error),
              const SizedBox(height: TCSpacing.lg),
              if (_isValidating)
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

  Widget _notice(String message, Color color) {
    return Semantics(
      liveRegion: true,
      child: Text(message, style: TCTextStyles.bodyMd.copyWith(color: color)),
    );
  }
}
