import 'package:flutter/widgets.dart';

/// The language the signed-out landing (and its demo) is drawn in.
///
/// `?lang=en` asks for English and `?lang=pt` for Portuguese, so the
/// portfolio can link to either. With neither, a browser that does not speak
/// Portuguese gets English. Signed in, the app is always Brazilian
/// Portuguese; this is only read while nobody is.
Locale landingLocale(Map<String, String> query, Locale browser) {
  switch (query['lang']) {
    case 'en':
      return const Locale('en');
    case 'pt':
      return const Locale('pt', 'BR');
  }
  return browser.languageCode == 'pt'
      ? const Locale('pt', 'BR')
      : const Locale('en');
}
