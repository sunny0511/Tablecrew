import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/features/onboarding/data/phone_send_rate_tracker.dart';

/// Unit tests for [PhoneSendRateTracker]'s pure windowing logic — the
/// client-side backing for docs/SCREEN_SPECIFICATIONS.md Screen 2's "5 send
/// attempts to the same number within 15 minutes" rule. Uses
/// `SharedPreferences.setMockInitialValues` (the standard flutter_test
/// in-memory fake for this package) rather than a hand-rolled fake, since
/// `shared_preferences` itself already ships one.
void main() {
  const phoneNumber = '+919876543210';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PhoneSendRateTracker> buildTracker() async {
    return PhoneSendRateTracker(await SharedPreferences.getInstance());
  }

  group('PhoneSendRateTracker', () {
    test('allows sending when no attempts have been recorded', () async {
      final tracker = await buildTracker();
      expect(tracker.canSend(phoneNumber), isTrue);
      expect(tracker.cooldownUntil(phoneNumber), isNull);
    });

    test('allows up to 5 attempts, blocks the 6th', () async {
      final tracker = await buildTracker();
      final now = DateTime(2026, 1, 1, 12);

      // Screen 2's rule is "after 5 send attempts ... the button disables"
      // — 5 sends are allowed, the 6th is what's blocked.
      for (var i = 0; i < 5; i++) {
        expect(tracker.canSend(phoneNumber, now: now), isTrue);
        await tracker.recordAttempt(phoneNumber, now: now);
      }

      expect(tracker.canSend(phoneNumber, now: now), isFalse);
      expect(tracker.cooldownUntil(phoneNumber, now: now), isNotNull);
    });

    test('cooldownUntil is 15 minutes after the oldest attempt', () async {
      final tracker = await buildTracker();
      final firstAttempt = DateTime(2026, 1, 1, 12);

      for (var i = 0; i < 5; i++) {
        await tracker.recordAttempt(
          phoneNumber,
          now: firstAttempt.add(Duration(seconds: i)),
        );
      }

      final cooldown = tracker.cooldownUntil(phoneNumber, now: firstAttempt);
      expect(cooldown, firstAttempt.add(const Duration(minutes: 15)));
    });

    test('attempts older than the 15-minute window no longer count',
        () async {
      final tracker = await buildTracker();
      final oldAttempt = DateTime(2026, 1, 1, 12);
      final now = oldAttempt.add(const Duration(minutes: 16));

      for (var i = 0; i < 5; i++) {
        await tracker.recordAttempt(phoneNumber, now: oldAttempt);
      }

      expect(tracker.canSend(phoneNumber, now: now), isTrue);
    });

    test('tracks different phone numbers independently', () async {
      final tracker = await buildTracker();
      final now = DateTime(2026, 1, 1, 12);
      const otherNumber = '+14155550100';

      for (var i = 0; i < 5; i++) {
        await tracker.recordAttempt(phoneNumber, now: now);
      }

      expect(tracker.canSend(phoneNumber, now: now), isFalse);
      expect(tracker.canSend(otherNumber, now: now), isTrue);
    });
  });
}
