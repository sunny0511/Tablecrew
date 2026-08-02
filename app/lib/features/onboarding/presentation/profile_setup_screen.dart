import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/photo_upload_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

const _minPhotoDimension = 400;
const _bioMaxLength = 140;
const _bioLiveRegionThreshold = 10;
const _firstNameMaxLength = 30;
const _avatarSize = 120.0;

/// A profile photo's client-side lifecycle through pick -> upload ->
/// moderation, per `docs/SCREEN_SPECIFICATIONS.md` Screen 5's Loading
/// States ("Uploading..." then "Reviewing your photo...").
enum _PhotoState {
  /// No photo picked yet — the dashed-outline "Add a photo" tile.
  empty,

  /// A picked image failed the 400x400 client-side minimum-resolution
  /// check and was rejected before upload.
  tooSmall,

  /// Offline when picked — bytes are held locally, waiting for
  /// connectivity before the raw upload starts.
  waitingForConnection,

  /// The raw upload to Cloud Storage is in flight.
  uploading,

  /// Uploaded; waiting on `watchPhotoModerationStatus`'s verdict.
  reviewing,

  /// A clean moderation verdict — `photoUploadId` is staged.
  approved,

  /// A flagged moderation verdict.
  flagged,

  /// The raw upload itself failed (e.g. a network drop mid-upload, not a
  /// moderation rejection).
  uploadFailed,
}

/// Screen 5 (Profile Setup), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// The photo picker is the screen's most involved piece: pick (camera or
/// library) -> a client-side 400x400 minimum-resolution check -> raw
/// upload to `users/{uid}/profile/pending/{uploadId}`
/// (`PhotoUploadRepository`) -> watch
/// `UserProfileRepository.watchPhotoModerationStatus` for the verdict.
/// "Continue" only enables once that verdict reads `"approved"` — never
/// merely once the raw upload finishes — per Screen 5's Milestone F5
/// correction to its Offline Behavior/Validation Rules.
///
/// **Deliberately not built:** the spec's "friendly (non-blocking) nudge
/// if the image looks obviously non-human (e.g., a pure logo or
/// screenshot)" and the "soft profanity/impersonation filter" on the
/// first-name field. Both are explicitly non-blocking UX niceties in the
/// spec's own wording, not enforcement (the resolution check and the
/// server-side SafeSearch moderation gate are the real, enforced checks
/// this screen already has); building either would need real content/text
/// classification this milestone has no model or service for. Disclosed
/// as a deferred nicety, not a silently skipped requirement.
///
/// **Name/bio "local draft" persistence** (Offline Behavior: "Name and
/// bio persist as a local draft immediately") is provided by writing every
/// keystroke into [OnboardingProfileDraftController], which — like every
/// other onboarding draft field — lives in in-memory Riverpod state, not
/// disk. That survives backgrounding within the same app process (the
/// scenario the spec's wording is actually addressing) but not an OS-level
/// process kill; true kill-survival would need a `SharedPreferences`-backed
/// draft store, which no onboarding screen in this milestone has built.
///
/// Added Milestone F5.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Creates the Profile Setup screen.
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _firstNameController = TextEditingController();
  final _lastInitialController = TextEditingController();
  final _bioController = TextEditingController();

  _PhotoState _photoState = _PhotoState.empty;
  Uint8List? _photoBytes;
  String? _contentType;
  String? _photoErrorMessage;

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<PhotoModerationStatus>? _moderationSubscription;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProfileDraftControllerProvider);
    _firstNameController.text = draft.displayName ?? '';
    _lastInitialController.text = draft.lastInitial ?? '';
    _bioController.text = draft.bio ?? '';

    final connectivity = Connectivity();
    unawaited(_checkInitialConnectivity(connectivity));
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    _firstNameController.addListener(_syncDraft);
    _lastInitialController.addListener(_syncDraft);
    _bioController.addListener(_syncDraft);
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_moderationSubscription?.cancel());
    _firstNameController.dispose();
    _lastInitialController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity(Connectivity connectivity) async {
    final result = await connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _isOffline = _isOfflineResult(result));
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!mounted) return;
    final wasOffline = _isOffline;
    final isOffline = _isOfflineResult(results);
    setState(() => _isOffline = isOffline);
    final bytes = _photoBytes;
    final contentType = _contentType;
    if (wasOffline &&
        !isOffline &&
        _photoState == _PhotoState.waitingForConnection &&
        bytes != null &&
        contentType != null) {
      unawaited(_upload(bytes, contentType));
    }
  }

  bool _isOfflineResult(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  void _syncDraft() {
    final lastInitial = _lastInitialController.text.trim();
    final bio = _bioController.text.trim();
    ref
        .read(onboardingProfileDraftControllerProvider.notifier)
        .setProfileFields(
          displayName: _firstNameController.text.trim(),
          lastInitial: lastInitial.isEmpty ? null : lastInitial,
          bio: bio.isEmpty ? null : bio,
        );
  }

  Future<void> _pickPhoto() async {
    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final dimensions = await _decodeDimensions(bytes);
    if (!mounted) return;
    if (dimensions.$1 < _minPhotoDimension ||
        dimensions.$2 < _minPhotoDimension) {
      setState(() {
        _photoState = _PhotoState.tooSmall;
        _photoErrorMessage =
            'That photo is too small — please choose one at least '
            '${_minPhotoDimension}x$_minPhotoDimension.';
      });
      return;
    }

    final contentType = picked.mimeType ?? 'image/jpeg';
    setState(() {
      _photoBytes = bytes;
      _contentType = contentType;
      _photoErrorMessage = null;
    });

    if (_isOffline) {
      setState(() => _photoState = _PhotoState.waitingForConnection);
      return;
    }
    await _upload(bytes, contentType);
  }

  Future<ImageSource?> _choosePhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<(int, int)> _decodeDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return (frame.image.width, frame.image.height);
  }

  Future<void> _upload(Uint8List bytes, String contentType) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _photoState = _PhotoState.uploading);
    try {
      final uploadId = await ref
          .read(photoUploadRepositoryProvider)
          .uploadPendingProfilePhoto(
            uid: uid,
            bytes: bytes,
            contentType: contentType,
          );
      if (!mounted) return;
      setState(() => _photoState = _PhotoState.reviewing);
      _watchModeration(uid: uid, uploadId: uploadId);
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _photoState = _PhotoState.uploadFailed);
    }
  }

  void _watchModeration({required String uid, required String uploadId}) {
    unawaited(_moderationSubscription?.cancel());
    _moderationSubscription = ref
        .read(userProfileRepositoryProvider)
        .watchPhotoModerationStatus(uid: uid, uploadId: uploadId)
        .listen((status) {
          if (!mounted) return;
          switch (status) {
            case PhotoModerationPending():
              break;
            case PhotoModerationApproved():
              ref
                  .read(onboardingProfileDraftControllerProvider.notifier)
                  .setPhotoUploadId(uploadId);
              setState(() => _photoState = _PhotoState.approved);
            case PhotoModerationFlagged():
              setState(() {
                _photoState = _PhotoState.flagged;
                _photoErrorMessage =
                    "That photo didn't pass our review — try another.";
                _photoBytes = null;
              });
          }
        });
  }

  bool get _canContinue {
    final firstName = _firstNameController.text.trim();
    return firstName.isNotEmpty &&
        firstName.length <= _firstNameMaxLength &&
        _photoState == _PhotoState.approved;
  }

  void _continue() {
    if (!_canContinue) return;
    context.goNamed('interests');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bioLength = _bioController.text.length;
    final bioNearLimit = _bioMaxLength - bioLength <= _bioLiveRegionThreshold;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Let's set up your profile",
                style: TCTextStyles.displayLg.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              Center(child: _buildPhotoTile(colors)),
              if (_photoErrorMessage != null) ...[
                const SizedBox(height: TCSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _photoErrorMessage!,
                    textAlign: TextAlign.center,
                    style: TCTextStyles.bodyMd.copyWith(color: colors.error),
                  ),
                ),
              ],
              const SizedBox(height: TCSpacing.lg),
              TextField(
                controller: _firstNameController,
                maxLength: _firstNameMaxLength,
                decoration: const InputDecoration(labelText: 'First name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: TCSpacing.md),
              TextField(
                controller: _lastInitialController,
                maxLength: 1,
                decoration: const InputDecoration(
                  labelText: 'Last initial (optional)',
                ),
              ),
              const SizedBox(height: TCSpacing.md),
              TextField(
                controller: _bioController,
                maxLength: _bioMaxLength,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A little about you (optional)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (bioNearLimit)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${_bioMaxLength - bioLength} characters left',
                    style: TCTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: TCSpacing.lg),
              ElevatedButton(
                onPressed: _canContinue ? _continue : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(ColorScheme colors) {
    final isBusy =
        _photoState == _PhotoState.uploading ||
        _photoState == _PhotoState.reviewing;

    if (isBusy) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkeletonPulse(width: _avatarSize, height: _avatarSize),
          const SizedBox(height: TCSpacing.sm),
          Text(
            _photoState == _PhotoState.uploading
                ? 'Uploading...'
                : 'Reviewing your photo...',
            style: TCTextStyles.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (_photoState == _PhotoState.approved && _photoBytes != null) {
      return GestureDetector(
        onTap: _pickPhoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_avatarSize / 2),
          child: Image.memory(
            _photoBytes!,
            width: _avatarSize,
            height: _avatarSize,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (_photoState == _PhotoState.waitingForConnection) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TCColors.neutral50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_outlined),
            ),
          ),
          const SizedBox(height: TCSpacing.sm),
          Text(
            "Uploading when you're back online",
            style: TCTextStyles.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // Empty/tooSmall/flagged/uploadFailed states all fall back to the
    // dashed-outline picker tile — Empty States: "a dashed-outline tile
    // with a camera icon and Inter microcopy ('Add a photo')."
    return Semantics(
      label: 'Add a photo',
      button: true,
      child: InkWell(
        onTap: _pickPhoto,
        borderRadius: BorderRadius.circular(_avatarSize / 2),
        child: Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.outline),
          ),
          child: Icon(
            Icons.camera_alt_outlined,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
