import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

void main() {
  group('notesPreview', () {
    test('is the first line with words, its spaces collapsed', () {
      expect(
        notesPreview('\n   \n  Ligar   pro\tLéo  \nDepois'),
        'Ligar pro Léo',
      );
    });

    test('skips a line that is only a link, which is drawn as a card', () {
      expect(
        notesPreview('https://example.com/planta.pdf\nConferir as medidas'),
        'Conferir as medidas',
      );
      expect(notesPreview('https://example.com'), '');
    });

    test('keeps a link inside a sentence', () {
      expect(
        notesPreview('Ver https://example.com antes'),
        'Ver https://example.com antes',
      );
    });
  });

  group('a card on the calendar', () {
    final start = DateTime(2026, 6, 10, 14);

    TimelineEvent card({String? project}) => TimelineEvent(
      id: 't',
      title: 'Orçamento da marcenaria',
      section: TimelineSection.dia,
      startTime: start,
      endTime: start.add(const Duration(minutes: 45)),
      durationMinutes: 45,
      notes: 'https://example.com/planta\nPedir foto da planta',
      projectId: project == null ? null : 'p',
      projectTitle: project,
    );

    Future<void> pump(
      WidgetTester tester,
      TimelineEvent card, {
      required double height,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 340,
                height: height,
                child: EventTile(card: card, preview: true),
              ),
            ),
          ),
        ),
      );
    }

    bool hasFolders() => find
        .byWidgetPredicate(
          (it) => it is AppIcon && it.iconData == AppIcons.things,
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('with room, says what its notes start with, under the title', (
      tester,
    ) async {
      await pump(tester, card(), height: 90);

      final title = tester.getRect(find.text('Orçamento da marcenaria'));
      final notes = tester.getRect(find.textContaining('Pedir foto'));
      expect(notes.top, greaterThan(title.bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without room, shows no notes at all and stays its size', (
      tester,
    ) async {
      await pump(tester, card(), height: 60);

      expect(find.textContaining('Pedir foto'), findsNothing);
      expect(tester.getSize(find.byType(EventTile)).height, 60);
      expect(tester.takeException(), isNull);
    });

    testWidgets('names its project first, or marks it when short', (
      tester,
    ) async {
      await pump(tester, card(project: 'Reforma do apê'), height: 90);
      expect(find.textContaining('Reforma do apê'), findsOneWidget);
      expect(hasFolders(), isFalse);

      await pump(tester, card(project: 'Reforma do apê'), height: 60);
      expect(find.textContaining('Reforma do apê'), findsNothing);
      expect(hasFolders(), isTrue);
    });

    testWidgets('in Lista, draws neither', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt', 'BR'),
          home: Scaffold(
            body: EventTile(card: card(project: 'Reforma')),
          ),
        ),
      );

      expect(find.textContaining('Pedir foto'), findsNothing);
      expect(hasFolders(), isFalse);
    });
  });
}
