import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's icon catalog, which this app is the other half of.
///
/// The two lists are the one part of the A2UI contract that cannot be checked
/// at either compile step: the server rejects an icon it does not know, this
/// app draws nothing for one it does not know, and a name added to only one
/// side fails silently in production as a missing glyph. So it is checked
/// here, by reading the server's own source.
File get _serverCatalog => File('../../../server/src/a2ui/a2ui.catalog.ts');

Set<String> _serverIconNames(String source) {
  final block = RegExp(
    r'export const ICON_NAMES = \[(.*?)\] as const;',
    dotAll: true,
  ).firstMatch(source);

  if (block == null) return <String>{};

  return RegExp(
    "'([a-zA-Z]+)'",
  ).allMatches(block.group(1)!).map((match) => match.group(1)!).toSet();
}

void main() {
  group('A2uiIcons', () {
    test('draws every icon the server is willing to send', () {
      final catalog = _serverCatalog;
      if (!catalog.existsSync()) {
        // The app is built on its own in some CI jobs, without the server
        // checked out beside it. Skipping beats failing on a missing file.
        return;
      }

      final expected = _serverIconNames(catalog.readAsStringSync());
      expect(expected, isNotEmpty, reason: 'The server catalog was unreadable');

      expect(
        A2uiIcons.names.toSet(),
        expected,
        reason: 'The app and server icon catalogs have drifted apart',
      );
    });

    test('returns null for an icon it does not know', () {
      expect(A2uiIcons.resolve('unicorn'), isNull);
      expect(A2uiIcons.resolve(null), isNull);
      expect(A2uiIcons.resolve('calendar'), isNotNull);
    });
  });
}
