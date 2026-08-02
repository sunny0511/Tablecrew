import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// Hand-written fake of [PermissionHandlerPlatform], installed via
/// `PermissionHandlerPlatform.instance = ...` — see
/// `FakeImagePickerPlatform`'s doc comment (`test/fakes/`) for why
/// `notification_priming_screen.dart`'s direct `Permission.notification`
/// use needs a fake at this package's own platform-interface seam rather
/// than a repository-fake override. Used by Screen 7's widget tests (task
/// #96e).
class FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  /// The status [requestPermissions] resolves every requested permission
  /// to. Defaults to [PermissionStatus.granted] since most tests aren't
  /// specifically exercising the denied path.
  PermissionStatus nextStatus = PermissionStatus.granted;

  /// Every `requestPermissions` call's argument list, in order.
  final List<List<Permission>> calls = [];

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    calls.add(permissions);
    return {for (final permission in permissions) permission: nextStatus};
  }
}
