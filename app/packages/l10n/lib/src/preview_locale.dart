import 'package:flutter/widgets.dart';

/// The language a preview entry point draws in.
///
/// Prints are read in the language the work is talked about in, so
/// `.tool/preview` builds with `--dart-define=PREVIEW_LANG=en`. The app
/// people use is always Brazilian Portuguese, and so is a preview built
/// without the define.
const Locale previewLocale = Locale(
  String.fromEnvironment('PREVIEW_LANG', defaultValue: 'pt'),
);
