import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://youtu.be/abc';

class _Previews implements LinkPreviews {
  final opened = <String>[];
  final pending = Completer<LinkPreview>();

  @override
  LinkPreview? cached(String url) => null;

  @override
  Future<LinkPreview> fetch(String url) => pending.future;

  @override
  void open(String url) => opened.add(url);
}

Widget _notes(LiveTextController controller, LinkPreviews previews) =>
    MaterialApp(
      home: Scaffold(
        body: LinkPreviewScope(
          previews: previews,
          child: TextField(
            controller: controller,
            maxLines: null,
            strutStyle: StrutStyle.disabled,
          ),
        ),
      ),
    );

void main() {
  group('AppLinkCard in the notes', () {
    testWidgets('pulses until its preview comes, then draws it', (
      tester,
    ) async {
      final previews = _Previews();
      await tester.pumpWidget(
        _notes(LiveTextController(text: 'Ver:\n$_url\n'), previews),
      );

      expect(find.byType(AppSkeleton), findsWidgets);
      expect(find.text('youtu.be'), findsOneWidget);

      previews.pending.complete(
        const LinkPreview(url: _url, title: 'Paraty', site: 'YouTube'),
      );
      await tester.pump();
      expect(find.byType(AppSkeleton), findsNothing);
      expect(find.text('Paraty'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
    });

    testWidgets('a tap on the card opens the link, not the keyboard', (
      tester,
    ) async {
      final previews = _Previews();
      final controller = LiveTextController(text: 'Ver:\n$_url\n');
      await tester.pumpWidget(_notes(controller, previews));

      await tester.tap(find.byType(AppLinkCard));
      await tester.pump(const Duration(milliseconds: 400));

      expect(previews.opened, [_url]);
      expect(controller.notes, 'Ver:\n$_url\n');
    });
  });
}
