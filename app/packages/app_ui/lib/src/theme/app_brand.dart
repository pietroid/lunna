import 'package:flutter/material.dart';

/// The two apps this code builds.
enum Brand {
  /// Dark, true black, a lime accent. What the app has always looked like.
  focus,

  /// Light, warm neutrals, a red accent and the crescent mark.
  lunna,
}

/// Which app this build is, fixed at compile time.
///
/// Set with `--dart-define=BRAND=focus|lunna` (the `env/<brand>.<env>.json`
/// files carry it). Everything that differs between the two apps reads from
/// here, and since it is a constant, the tokens that depend on it
/// (`AppColors` and friends) stay `const` and every call site stays as it
/// is. A build without the define is Focus, which keeps the tests on the
/// look they were written against.
abstract final class AppBrand {
  static const String _id = String.fromEnvironment(
    'BRAND',
    defaultValue: 'focus',
  );

  /// Whether this build is Lunna.
  static const bool isLunna = _id == 'lunna';

  /// This build's brand.
  static const Brand current = isLunna ? Brand.lunna : Brand.focus;

  /// The brand's key, as the strings select on it (`appName` and the copy
  /// that names the app).
  static const String id = isLunna ? 'lunna' : 'focus';

  /// Whether the app is drawn light or dark. Each brand ships one.
  static const Brightness brightness = isLunna
      ? Brightness.light
      : Brightness.dark;

  /// The square app mark, bundled in `app_ui` (pass `package: 'app_ui'`).
  static const String markAsset = isLunna
      ? 'assets/brand/lunna.png'
      : 'assets/brand/focus.png';
}
