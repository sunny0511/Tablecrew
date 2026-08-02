import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';

const _illustrationSize = 96.0;

/// Screen 7 (Notification Permission Priming), the last onboarding screen,
/// `docs/SCREEN_SPECIFICATIONS.md`.
///
/// Uses `permission_handler` rather than `firebase_messaging` — this
/// screen only needs to trigger the native OS permission dialog per its
/// own API Calls note ("None — this screen only triggers the native OS
/// permission API; no business endpoint call"). Actually registering an
/// FCM push token with the backend is explicitly deferred to Milestone F8
/// (`features/account/README.md`), so pulling in the much heavier
/// `firebase_messaging` dependency now, before anything reads a token,
/// would be building ahead of that milestone's actual need.
///
/// Android 13+ additionally requires the `POST_NOTIFICATIONS` manifest
/// permission for the system dialog to appear at all — added to
/// `android/app/src/main/AndroidManifest.xml` alongside this screen.
///
/// **Disclosed, not built:** the spec's `onboarding_step_completed`
/// analytics event (`step: "notification_priming"`,
/// `permission_granted: true/false`) isn't emitted — no analytics
/// SDK/wrapper exists anywhere in this Flutter codebase yet
/// (`firebase_analytics` is still unpinned, per `pubspec.yaml`'s own
/// Milestone F0 note), matching every other onboarding screen's identical
/// gap this milestone, not a regression specific to this screen.
///
/// Added Milestone F5.
class NotificationPrimingScreen extends StatelessWidget {
  /// Creates the Notification Permission Priming screen.
  const NotificationPrimingScreen({super.key});

  Future<void> _turnOnNotifications(BuildContext context) async {
    // The result isn't branched on — Exit Points is unconditionally Home
    // either way ("permission grant/deny is an OS-level binary outcome,
    // not a validated form field," Validation Rules). Still awaited so
    // the OS dialog has actually been dismissed before navigating away.
    await Permission.notification.request();
    if (!context.mounted) return;
    context.goNamed('home');
  }

  void _notNow(BuildContext context) {
    context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accessibility Notes: "The illustration is marked
              // decorative (no meaningful alt text needed beyond the
              // surrounding copy)."
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: _illustrationSize,
                    height: _illustrationSize,
                    decoration: const BoxDecoration(
                      color: TCColors.primary100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      size: _illustrationSize / 2,
                      color: TCColors.primary600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              Text(
                "Don't miss your Table",
                textAlign: TextAlign.center,
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                'Table invites, RSVP and chat updates, and day-of '
                "reminders — we'll only notify you about the Tables you're "
                'part of.',
                textAlign: TextAlign.center,
                style: TCTextStyles.bodyMd.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.xl),
              ElevatedButton(
                onPressed: () => _turnOnNotifications(context),
                child: const Text('Turn on notifications'),
              ),
              const SizedBox(height: TCSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () => _notNow(context),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
