import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/identity_upload_repository.dart';
import 'package:tablecrew/data/identity_verification_repository.dart';
import 'package:tablecrew/features/identity/application/identity_verification_controller.dart';
import 'package:tablecrew/features/identity/presentation/identity_verification_screen.dart';

import '../../../fakes/fake_identity_repositories.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 8 (Identity Verification) — Milestone F7,
/// ADR 0007.
///
/// Several of these assert on *copy*, which is unusual for this codebase
/// and deliberate here. ADR 0007 and docs/SECURITY.md both record that
/// manual review is not a liveness check and that the held-for-review
/// state must not disclose the existence of a report. Those are the two
/// promises most likely to be broken by an innocent-looking copy edit, so
/// they are pinned as tests rather than left as comments.
void main() {
  late FakeIdentityUploadRepository uploads;
  late FakeIdentityVerificationRepository verification;
  late ProviderContainer container;

  // A real 1x1 PNG — Image.memory throws on undecodable bytes, so the
  // capture-preview tests need genuine image data, not [1, 2, 3].
  final tinyPng = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  setUp(() {
    uploads = FakeIdentityUploadRepository();
    verification = FakeIdentityVerificationRepository();
    container = ProviderContainer(
      overrides: [
        identityUploadRepositoryProvider.overrideWithValue(uploads),
        identityVerificationRepositoryProvider.overrideWithValue(verification),
        currentUidProvider.overrideWithValue('alice'),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/identity-verification',
      initialName: 'identity-verification',
      initialScreen: const IdentityVerificationScreen(),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
  }

  void seedStatus(IdentityVerificationStatus status) {
    verification
      ..statusSeed = status
      ..pendingSubmissionId = 'submission-open';
  }

  testWidgets('capture view explains what this is, and what it is not',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text("Let's verify it's really you"), findsOneWidget);
    expect(find.textContaining('it is not a background check'), findsOneWidget);
    expect(find.textContaining('Government ID'), findsOneWidget);
    expect(find.textContaining('Selfie holding your ID'), findsOneWidget);
  });

  testWidgets('no copy on the capture view claims a liveness check',
      (tester) async {
    // ADR 0007: a human comparing a selfie to an ID does not establish
    // physical presence. Any wording implying it would be false during
    // Phase 0, so it is barred here rather than trusted to review.
    await pumpScreen(tester);

    for (final banned in ['liveness', 'physically present', 'really here']) {
      expect(
        find.textContaining(banned, findRichText: true),
        findsNothing,
        reason: 'Screen 8 copy must not claim liveness (ADR 0007)',
      );
    }
  });

  testWidgets('Submit is disabled until both images are captured',
      (tester) async {
    await pumpScreen(tester);

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit for review'),
          )
          .onPressed,
      isNull,
    );

    container.read(identityVerificationControllerProvider.notifier)
      ..setIdDocument(tinyPng, 'image/png')
      ..setSelfie(tinyPng, 'image/png');
    await settle(tester);

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit for review'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the pending state reads as a resting state, not a spinner',
      (tester) async {
    seedStatus(const IdentityPendingReview());
    await pumpScreen(tester);

    expect(find.text('Waiting for review'), findsOneWidget);
    expect(find.textContaining('You can close the app'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets("a rejection shows the reviewer's own reason and a retry",
      (tester) async {
    seedStatus(const IdentityRejected('The ID photo is too blurry to read.'));
    await pumpScreen(tester);

    expect(find.text('The ID photo is too blurry to read.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });

  testWidgets('held-for-review never discloses that a report exists',
      (tester) async {
    // docs/SECURITY.md's silent-reporting guarantee: telling the subject
    // of an open report that one exists, and when, is exactly the leak
    // that rule prevents.
    seedStatus(const IdentityHeldForReview());
    await pumpScreen(tester);

    expect(find.text('Taking a closer look'), findsOneWidget);
    for (final banned in ['report', 'reported', 'flagged']) {
      expect(
        find.textContaining(banned, findRichText: true),
        findsNothing,
        reason: 'held_for_review copy must not disclose a report',
      );
    }
  });

  testWidgets('approval offers a way back to what the user was doing',
      (tester) async {
    seedStatus(const IdentityApproved());
    await pumpScreen(tester);

    expect(find.text("You're verified"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });
}
