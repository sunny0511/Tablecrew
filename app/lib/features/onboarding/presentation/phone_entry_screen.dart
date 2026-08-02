import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_phone_flow_controller.dart';
import 'package:tablecrew/features/onboarding/data/phone_send_rate_tracker.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

/// Screen 2 (Phone Number Entry), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// Country selection + live-formatted number entry are both handled by
/// `intl_phone_field`'s single combined widget, matching this screen's two
/// listed UI components ("Country-code selector," "phone number field with
/// live formatting") as one cohesive control rather than two hand-wired
/// pieces — see `pubspec.yaml`'s dependency comment for why this package
/// was chosen over hand-rolling libphonenumber validation.
///
/// Added Milestone F5.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  /// Creates the Phone Number Entry screen.
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  String? _completeNumber;
  bool _numberIsValid = false;
  bool _isOffline = false;
  DateTime? _cooldownUntil;
  Timer? _uiTicker;
  StreamSubscription<bool>? _reconnectSubscription;

  @override
  void dispose() {
    _uiTicker?.cancel();
    unawaited(_reconnectSubscription?.cancel());
    super.dispose();
  }

  Future<void> _onSendPressed() async {
    final phoneNumber = _completeNumber;
    if (phoneNumber == null || !_numberIsValid) return;

    final connectivity = ref.read(connectivityRepositoryProvider);
    if (await connectivity.isOffline()) {
      if (!mounted) return;
      setState(() => _isOffline = true);
      _waitForReconnectThenSend(phoneNumber, connectivity);
      return;
    }

    await _attemptSend(phoneNumber);
  }

  /// Screen 2's offline behavior: "the request auto-retries on reconnect
  /// for up to 60 seconds before failing explicitly and asking for a
  /// manual retry" — the manual-retry path is just the same button, since
  /// clearing [_isOffline] after the 60s window re-enables it without a
  /// fresh connectivity check blocking the tap.
  void _waitForReconnectThenSend(
    String phoneNumber,
    ConnectivityRepository connectivity,
  ) {
    unawaited(_reconnectSubscription?.cancel());
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    _reconnectSubscription = connectivity.offlineChanges.listen((isOffline) {
      if (!mounted || isOffline) return;
      unawaited(_reconnectSubscription?.cancel());
      setState(() => _isOffline = false);
      unawaited(_attemptSend(phoneNumber));
    });
    _uiTicker?.cancel();
    _uiTicker = Timer(const Duration(seconds: 60), () {
      if (!mounted || DateTime.now().isBefore(deadline)) return;
      unawaited(_reconnectSubscription?.cancel());
      if (mounted) setState(() => _isOffline = false);
    });
  }

  int _cooldownMinutesRemaining() {
    return _cooldownUntil!.difference(DateTime.now()).inMinutes + 1;
  }

  Future<void> _attemptSend(String phoneNumber) async {
    final tracker = await ref.read(phoneSendRateTrackerProvider.future);
    if (!tracker.canSend(phoneNumber)) {
      if (!mounted) return;
      setState(() => _cooldownUntil = tracker.cooldownUntil(phoneNumber));
      _startCooldownTicker();
      return;
    }

    await tracker.recordAttempt(phoneNumber);
    await ref
        .read(onboardingPhoneFlowControllerProvider.notifier)
        .sendCode(phoneNumber);

    if (!mounted) return;
    final status = ref.read(onboardingPhoneFlowControllerProvider).status;
    if (status == OnboardingPhoneFlowStatus.codeSent ||
        status == OnboardingPhoneFlowStatus.autoVerified) {
      unawaited(context.pushNamed('otp'));
    }
  }

  void _startCooldownTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final until = _cooldownUntil;
      if (until == null || DateTime.now().isAfter(until)) {
        _uiTicker?.cancel();
        if (mounted) setState(() => _cooldownUntil = null);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flowState = ref.watch(onboardingPhoneFlowControllerProvider);
    final isSending = flowState.status == OnboardingPhoneFlowStatus.sending;
    final isCoolingDown = _cooldownUntil != null;
    final canSubmit = _numberIsValid && !isSending && !isCoolingDown;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TCSpacing.xxl),
              Text(
                "What's your number?",
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                "We'll text you a code to confirm it's really you.",
                style: TCTextStyles.bodyLg.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              // intl_phone_field 3.2.0 (the real `flutter pub add`-resolved
              // version — see pubspec.yaml) has no `autofillHints`
              // parameter; an earlier draft assumed one against this
              // package's general documented surface without checking this
              // exact version. The underlying field still gets the
              // platform's default telephone-number keyboard/suggestions.
              IntlPhoneField(
                decoration: const InputDecoration(labelText: 'Phone number'),
                onChanged: (phone) {
                  _completeNumber = phone.completeNumber;
                  final valid = phone.isValidNumber();
                  if (valid != _numberIsValid) {
                    setState(() => _numberIsValid = valid);
                  }
                },
              ),
              const SizedBox(height: TCSpacing.md),
              if (_isOffline)
                _InlineNotice(
                  message: "You're offline — we'll retry automatically.",
                  color: colors.error,
                )
              else if (isCoolingDown)
                _InlineNotice(
                  message: 'Too many attempts — try again in '
                      '${_cooldownMinutesRemaining()} min.',
                  color: colors.error,
                )
              else if (flowState.status ==
                      OnboardingPhoneFlowStatus.sendFailed &&
                  flowState.exception != null)
                _InlineNotice(
                  message: flowState.exception!.message,
                  color: colors.error,
                ),
              if (_isOffline || isCoolingDown || flowState.exception != null)
                const SizedBox(height: TCSpacing.md),
              if (isSending)
                const SkeletonPulse(
                  width: double.infinity,
                  height: TCSpacing.minTouchTarget,
                )
              else
                ElevatedButton(
                  onPressed: canSubmit ? _onSendPressed : null,
                  child: const Text('Send Code'),
                ),
              const SizedBox(height: TCSpacing.lg),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                style: TCTextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared inline error/notice row — Screen 2's offline/rate-limit/send-error
/// states, and Screen 3's confirm-error state, all render "announced via a
/// live region, not conveyed by color alone" (Screen 2/3 Accessibility
/// Notes), so this always pairs the [color] with a [Semantics] live-region
/// text, never color alone.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(message, style: TCTextStyles.bodyMd.copyWith(color: color)),
    );
  }
}
