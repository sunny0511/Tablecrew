import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/photo_upload_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/features/onboarding/presentation/profile_setup_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_image_picker_platform.dart';
import '../../../fakes/fake_photo_upload_repository.dart';
import '../../../fakes/fake_user_profile_repository.dart';
import '../../../support/fake_image_bytes.dart';
import '../../../support/test_router.dart';

const _uid = 'uid-1';

/// Widget tests for Screen 5 (Profile Setup), task #96e — the screen the
/// milestone's plugin-mocking infrastructure exists for.
///
/// Photo-pipeline note: `_decodeDimensions` runs picked bytes through
/// `ui.instantiateImageCodec`, a real engine codec whose future only
/// completes on the real event loop — under `testWidgets`' fake-async
/// zone it stalls forever, so every step from tapping the picker onward
/// runs the real event loop briefly via [WidgetTester.runAsync] before
/// pumping. The PNG fixtures themselves are generated in [setUpAll] for
/// the same reason (`Picture.toImage`/`toByteData` are engine calls too),
/// which runs on the real event loop rather than inside a test body.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List bigImage;
  late Uint8List smallImage;

  setUpAll(() async {
    bigImage = await fakeImageBytes(400);
    smallImage = await fakeImageBytes(100);
  });

  late FakeConnectivityRepository connectivity;
  late FakeUserProfileRepository userProfileRepository;
  late FakePhotoUploadRepository photoUploadRepository;
  late FakeImagePickerPlatform imagePicker;
  late ProviderContainer container;

  setUp(() {
    connectivity = FakeConnectivityRepository();
    userProfileRepository = FakeUserProfileRepository();
    photoUploadRepository = FakePhotoUploadRepository();
    imagePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = imagePicker;
    container = ProviderContainer(
      overrides: [
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
        photoUploadRepositoryProvider.overrideWithValue(photoUploadRepository),
        currentUidProvider.overrideWithValue(_uid),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(connectivity.dispose);
    addTearDown(userProfileRepository.dispose);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/profile-setup',
      initialName: 'profile-setup',
      initialScreen: const ProfileSetupScreen(),
      destinations: const {'interests': '/interests'},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A bounded stand-in for `pumpAndSettle()` for any moment the
  /// "Uploading..."/"Reviewing your photo..." states may be on screen:
  /// their `SkeletonPulse` runs a `repeat(reverse: true)`
  /// `AnimationController`, which perpetually schedules frames, so
  /// `pumpAndSettle()` (which waits for *no* pending frames) times out —
  /// the same structural issue `otp_screen_test.dart`'s countdown ticker
  /// has, confirmed against this file's first run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Taps the photo tile, picks "Choose from library", and lets the real
  /// event loop run the codec/upload chain to completion.
  Future<void> pickPhoto(WidgetTester tester, Uint8List bytes) async {
    imagePicker.nextImages.add(
      XFile.fromData(bytes, mimeType: 'image/png'),
    );
    await tester.tap(find.bySemanticsLabel('Add a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
  }

  ElevatedButton continueButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
  }

  testWidgets('renders with an empty photo tile and Continue disabled', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text("Let's set up your profile"), findsOneWidget);
    expect(find.bySemanticsLabel('Add a photo'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('rejects a photo under 400x400 before any upload', (
    tester,
  ) async {
    await pumpScreen(tester);

    await pickPhoto(tester, smallImage);

    expect(find.textContaining('too small'), findsOneWidget);
    expect(photoUploadRepository.uploads, isEmpty);
  });

  testWidgets(
      'a valid photo uploads, shows Reviewing, then unlocks Continue once '
      'moderation approves (with a name entered)', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Ada',
    );
    await tester.pump();

    await pickPhoto(tester, bigImage);

    expect(photoUploadRepository.uploads.single.uid, _uid);
    expect(find.text('Reviewing your photo...'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);

    userProfileRepository.emitModerationStatus(
      _uid,
      'upload-1',
      const PhotoModerationApproved('https://example.com/photo.jpg'),
    );
    await tester.pumpAndSettle();

    expect(continueButton(tester).onPressed, isNotNull);
    expect(
      container.read(onboardingProfileDraftControllerProvider).photoUploadId,
      'upload-1',
      reason: 'an approved verdict must stage the uploadId into the draft',
    );

    // The button sits below the 600px test viewport's fold once the photo
    // tile and three text fields are above it — scroll it into view first,
    // or the tap lands on nothing (a real warnIfMissed miss, not flake).
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:interests'), findsOneWidget);
  });

  testWidgets(
      'a flagged verdict shows the rejection message and keeps Continue '
      'disabled', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Ada',
    );
    await tester.pump();
    await pickPhoto(tester, bigImage);

    userProfileRepository.emitModerationStatus(
      _uid,
      'upload-1',
      const PhotoModerationFlagged(),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("That photo didn't pass our review — try another."),
      findsOneWidget,
    );
    expect(continueButton(tester).onPressed, isNull);
    expect(
      container.read(onboardingProfileDraftControllerProvider).photoUploadId,
      isNull,
    );
  });

  testWidgets('picking while offline defers the upload until reconnection', (
    tester,
  ) async {
    connectivity = FakeConnectivityRepository(initiallyOffline: true);
    container = ProviderContainer(
      overrides: [
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
        photoUploadRepositoryProvider.overrideWithValue(photoUploadRepository),
        currentUidProvider.overrideWithValue(_uid),
      ],
    );
    addTearDown(container.dispose);
    await pumpScreen(tester);

    await pickPhoto(tester, bigImage);

    expect(
      find.text("Uploading when you're back online"),
      findsOneWidget,
    );
    expect(photoUploadRepository.uploads, isEmpty);

    connectivity.setOffline(isOffline: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);

    expect(photoUploadRepository.uploads, hasLength(1));
    expect(find.text('Reviewing your photo...'), findsOneWidget);
  });

  testWidgets('a failed upload falls back to the picker tile', (
    tester,
  ) async {
    photoUploadRepository.uploadError = Exception('network drop');
    await pumpScreen(tester);

    await pickPhoto(tester, bigImage);

    expect(find.bySemanticsLabel('Add a photo'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('name and bio keystrokes stage into the shared draft', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Ada',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'A little about you (optional)'),
      'Loves board games.',
    );
    await tester.pump();

    final draft = container.read(onboardingProfileDraftControllerProvider);
    expect(draft.displayName, 'Ada');
    expect(draft.bio, 'Loves board games.');
  });
}
