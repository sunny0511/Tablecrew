import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Hand-written fake of [ImagePickerPlatform], installed via
/// `ImagePickerPlatform.instance = ...` — `image_picker`'s real platform
/// implementations talk to a native platform channel that throws
/// `MissingPluginException` under a plain `flutter test`, the same gap
/// `ConnectivityRepository`'s own doc comment describes for
/// `connectivity_plus`. Unlike the repository-wrapped plugins elsewhere in
/// this codebase, `profile_setup_screen.dart` calls `ImagePicker().pickImage`
/// directly (no repository layer sits in front of it — see that screen's
/// doc comment on why the photo pipeline's *upload* half is
/// `PhotoUploadRepository`-wrapped but the *pick* half isn't), so the test
/// double has to sit at `image_picker`'s own platform-interface seam
/// instead. Used by Screen 5's widget tests (task #96e).
class FakeImagePickerPlatform extends ImagePickerPlatform {
  /// Queue of values [getImageFromSource] returns, consumed FIFO — `null`
  /// simulates the user cancelling the picker.
  final List<XFile?> nextImages = [];

  /// Every `source` [getImageFromSource] was called with, in order.
  final List<ImageSource> calls = [];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls.add(source);
    return nextImages.isEmpty ? null : nextImages.removeAt(0);
  }
}
