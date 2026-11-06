/// Lunna's strings.
///
/// Every user-facing sentence in the app lives in `lib/arb/app_pt.arb`, in
/// Brazilian Portuguese, and is read through `context.l10n`. The app always
/// runs in Portuguese; `app_en.arb` holds the same strings in English, only
/// for previews and prints (`previewLocale`). Code, comments and logs stay in
/// English.
library;

import 'package:flutter/widgets.dart';
import 'package:l10n/src/gen/app_localizations.dart';

export 'package:l10n/src/gen/app_localizations.dart';
export 'package:l10n/src/preview_locale.dart';

/// Reads the strings off a [BuildContext].
extension AppLocalizationsX on BuildContext {
  /// The strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
