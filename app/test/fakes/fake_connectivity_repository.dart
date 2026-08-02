import 'dart:async';

import 'package:tablecrew/data/connectivity_repository.dart';

/// Hand-written fake of [ConnectivityRepository]
/// (`app/lib/data/connectivity_repository.dart`) — a plain, synchronously
/// controllable stand-in for `connectivity_plus`'s platform channel, which
/// throws `MissingPluginException` under a plain `flutter test` (see that
/// interface's own doc comment for why the split exists). Used by
/// `AccountSetupController`'s tests and the 4 onboarding screens' widget
/// tests (Milestone F5 task #96).
class FakeConnectivityRepository implements ConnectivityRepository {
  /// Creates a fake starting online unless [initiallyOffline] is `true`.
  FakeConnectivityRepository({bool initiallyOffline = false})
      : _isOffline = initiallyOffline;

  bool _isOffline;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOffline() async => _isOffline;

  @override
  Stream<bool> get offlineChanges => _controller.stream;

  /// Test-side hook: flips the fake's connectivity state and emits it on
  /// [offlineChanges], simulating the device going offline/online.
  void setOffline({required bool isOffline}) {
    _isOffline = isOffline;
    _controller.add(isOffline);
  }

  /// Closes the underlying stream controller — call from a test's
  /// `tearDown`/`addTearDown` to avoid a "Stream not closed" warning
  /// between tests.
  Future<void> dispose() => _controller.close();
}
