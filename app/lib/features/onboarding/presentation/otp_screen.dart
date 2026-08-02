import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_phone_flow_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

const _codeLength = 6;
const _resendCooldown = Duration(seconds: 30);
const _codeExpiry = Duration(minutes: 5);

/// Screen 3 (OTP Verification), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// `pinput` renders the 6-digit input as a single underlying [TextField]
/// with custom per-digit painting, matching this screen's Accessibility
/// Note directly: "exposed to assistive tech as a single accessible text
/// field with a 6-digit numeric hint, not six separately unlabeled boxes."
///
/// Added Milestone F5.
class OtpScreen extends ConsumerStatefulWidget {
  /// Creates the OTP Verification screen.
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  bool _isOffline = false;
  String? _pendingOfflineCode;
  Timer? _uiTicker;
  StreamSubscription<List<ConnectivityResult>>? _reconnectSubscription;

  @override
  void dispose() {
    _pinController.dispose();
    _uiTicker?.cancel();
    unawaited(_reconnectSubscription?.cancel());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Re-render every second so the resend countdown and code-expiry
    // notice stay live without the user needing to interact.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onCompleted(String code) async {
    final connectivity = Connectivity();
    if (_isOfflineResult(await connectivity.checkConnectivity())) {
      setState(() {
        _isOffline = true;
        _pendingOfflineCode = code;
      });
      _waitForReconnectThenConfirm(connectivity);
      return;
    }
    await _confirm(code);
  }

  void _waitForReconnectThenConfirm(Connectivity connectivity) {
    unawaited(_reconnectSubscription?.cancel());
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    _reconnectSubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final code = _pendingOfflineCode;
      if (!mounted || _isOfflineResult(results) || code == null) return;
      unawaited(_reconnectSubscription?.cancel());
      setState(() => _isOffline = false);
      unawaited(_confirm(code));
    });
    Timer(const Duration(seconds: 60), () {
      if (!mounted || DateTime.now().isBefore(deadline)) return;
      unawaited(_reconnectSubscription?.cancel());
      if (mounted) setState(() => _isOffline = false);
    });
  }

  bool _isOfflineResult(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  Future<void> _confirm(String code) async {
    final controller = ref.read(onboardingPhoneFlowControllerProvider.notifier);
    await controller.confirmCode(code);
    if (!mounted) return;

    final state = ref.read(onboardingPhoneFlowControllerProvider);
    if (state.status == OnboardingPhoneFlowStatus.confirmFailed) {
      _pinController.clear();
      return;
    }
    if (state.status != OnboardingPhoneFlowStatus.confirmed) return;

    final uid = state.credential?.user?.uid;
    if (uid == null) return;
    final hasProfile = await ref
        .read(userProfileRepositoryProvider)
        .hasCompletedProfile(uid);
    if (!mounted) return;
    if (hasProfile) {
      context.goNamed('home');
    } else {
      context.goNamed('dob');
    }
  }

  void _resend() {
    _pinController.clear();
    unawaited(
      ref.read(onboardingPhoneFlowControllerProvider.notifier).resendCode(),
    );
  }

  void _editNumber() {
    context.pop();
  }

  int _lockSecondsRemaining(DateTime lockedUntil) {
    return lockedUntil.difference(DateTime.now()).inSeconds.clamp(0, 60);
  }

  String _maskedNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.length < 2) return phoneNumber ?? '';
    final lastTwo = phoneNumber.substring(phoneNumber.length - 2);
    return '•• ••$lastTwo';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flowState = ref.watch(onboardingPhoneFlowControllerProvider);
    final isConfirming =
        flowState.status == OnboardingPhoneFlowStatus.confirming;
    final isLocked = flowState.status == OnboardingPhoneFlowStatus.locked &&
        flowState.lockedUntil != null &&
        DateTime.now().isBefore(flowState.lockedUntil!);
    final codeExpired = flowState.codeSentAt != null &&
        DateTime.now().difference(flowState.codeSentAt!) > _codeExpiry;
    final canResend = !isConfirming &&
        (flowState.codeSentAt == null ||
            DateTime.now().difference(flowState.codeSentAt!) >
                _resendCooldown ||
            codeExpired);

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: TCTextStyles.headingLg.copyWith(color: colors.onSurface),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
        border: Border.all(color: colors.outline),
      ),
    );
    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: colors.error, width: 1.5),
    );

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the code we sent to '
                '${_maskedNumber(flowState.phoneNumber)}',
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              if (isConfirming)
                const Center(
                  child: SkeletonPulse(
                    width: 6 * 48.0 + 5 * TCSpacing.sm,
                    height: 56,
                  ),
                )
              else
                Center(
                  child: Pinput(
                    length: _codeLength,
                    controller: _pinController,
                    enabled: !isLocked,
                    autofocus: true,
                    defaultPinTheme: defaultPinTheme,
                    errorPinTheme: errorPinTheme,
                    forceErrorState:
                        flowState.status ==
                        OnboardingPhoneFlowStatus.confirmFailed,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // pinput 6.0.2 (the real `flutter pub add`-resolved
                    // version — see pubspec.yaml) has no
                    // `androidSmsAutofillMethod` parameter; an earlier draft
                    // assumed one against pinput's general documented
                    // feature set without checking this exact version.
                    // Autofill still works via the underlying TextField's
                    // platform-default behavior — this only opts out of
                    // pinput's *own* SMS Retriever wiring, not autofill
                    // entirely.
                    onCompleted: _onCompleted,
                  ),
                ),
              const SizedBox(height: TCSpacing.md),
              if (_isOffline)
                _notice(
                  "You're offline — we'll retry automatically.",
                  colors.error,
                )
              else if (isLocked)
                _notice(
                  'Too many attempts — try again in '
                  '${_lockSecondsRemaining(flowState.lockedUntil!)}s.',
                  colors.error,
                )
              else if (codeExpired)
                _notice(
                  'This code has expired — send a new one below.',
                  colors.error,
                )
              else if (flowState.status ==
                      OnboardingPhoneFlowStatus.confirmFailed &&
                  flowState.exception != null)
                _notice("That code didn't match — try again.", colors.error),
              const SizedBox(height: TCSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _editNumber,
                    child: const Text('Edit number'),
                  ),
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      canResend ? 'Resend code' : 'Resend code (wait)',
                    ),
                  ),
                ],
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
