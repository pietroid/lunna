import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  const english = Locale('en', 'US');
  const portuguese = Locale('pt', 'BR');

  group('landingLocale', () {
    test('lang=en is English, whatever the browser speaks', () {
      expect(landingLocale({'lang': 'en'}, portuguese), const Locale('en'));
    });

    test('lang=pt is Portuguese, whatever the browser speaks', () {
      expect(landingLocale({'lang': 'pt'}, english), portuguese);
    });

    test('a Portuguese browser gets Portuguese', () {
      expect(landingLocale({}, const Locale('pt', 'PT')), portuguese);
    });

    test('any other browser gets English', () {
      expect(landingLocale({}, const Locale('de')), const Locale('en'));
      expect(landingLocale({'lang': 'fr'}, english), const Locale('en'));
    });
  });
}
