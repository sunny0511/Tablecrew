import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:tablecrew/core/theme/app_theme.dart';

/// Global Alchemist configuration for every test in this package, per
/// Recommendation R2 and Alchemist's own Recommended Setup Guide
/// (https://github.com/Betterment/alchemist/blob/main/RECOMMENDED_SETUP_GUIDE.md).
///
/// Sets TableCrew's real light theme (`docs/DESIGN_SYSTEM.md`, via
/// `TCAppTheme.light()`) as the default for every golden test, so component
/// goldens render against the actual app theme rather than Flutter's
/// generic `ThemeData.light()`/`.fallback()` default.
///
/// Disables platform ("readable") golden tests in CI: those goldens are
/// inherently unstable across host OSes (font rendering differs between
/// macOS/Linux/Windows — see `.gitignore`'s comment on why they're not
/// committed), so only the Ahem-font, platform-agnostic "ci/" goldens run
/// there. `.github/workflows/ci.yml`'s `test-flutter` job passes
/// `--dart-define=CI=true` so `bool.fromEnvironment('CI')` below actually
/// resolves true on that runner — a plain `Platform.environment['CI']`
/// check would not work here, since `bool.fromEnvironment` only sees
/// compile-time `--dart-define` values, not process environment variables.
/// Locally (no `--dart-define=CI=true` passed), both platform and CI
/// goldens run, so a developer gets a human-readable reference image in
/// `test/**/goldens/<platform>/` for visual debugging.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const isRunningInCi = bool.fromEnvironment('CI');

  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: TCAppTheme.light(),
      platformGoldensConfig: const PlatformGoldensConfig(
        // Real `flutter analyze` flags this as redundant-with-default,
        // because a plain local/analyzer pass never sets the CI
        // --dart-define, so `isRunningInCi` const-folds to false and
        // `!isRunningInCi` const-folds to true - PlatformGoldensConfig's
        // own default. Kept explicit anyway: this line is what actually
        // disables platform goldens when .github/workflows/ci.yml's
        // test-flutter job *does* pass --dart-define=CI=true; removing it
        // would silently break that.
        // ignore: avoid_redundant_argument_values
        enabled: !isRunningInCi,
      ),
    ),
    run: testMain,
  );
}
