import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('pt'));

  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Scaffold(body: card),
    ),
  );

  group('TaskCard', () {
    testWidgets('plays from the button on its left, and opens on a tap', (
      tester,
    ) async {
      final calls = <String>[];
      await pump(
        tester,
        TaskCard(
          title: 'Post de novembro',
          subtitle: 'Roteiro',
          onPlay: () => calls.add('play'),
          onTap: () => calls.add('open'),
        ),
      );

      expect(find.byTooltip(l10n.controlStartNow), findsOneWidget);
      await tester.tap(find.byType(TaskPlayButton));
      await tester.tap(find.text('Post de novembro'));
      expect(calls, ['play', 'open']);
      // Not begun: no controls and no bar.
      expect(find.byTooltip(l10n.controlDone), findsNothing);
      expect(find.byType(TaskCardBar), findsNothing);
    });

    testWidgets('draws pause while it runs', (tester) async {
      await pump(
        tester,
        TaskCard(title: 'Roteiro', now: true, playing: true, onPlay: () {}),
      );

      expect(find.byTooltip(l10n.controlPause), findsOneWidget);
    });

    testWidgets('has no button without play, as a fixed block', (
      tester,
    ) async {
      await pump(tester, const TaskCard(title: 'Reunião'));

      expect(find.byType(TaskPlayButton), findsNothing);
    });

    testWidgets('answers −10, +10 and ✓, and fades one it cannot', (
      tester,
    ) async {
      final calls = <String>[];
      await pump(
        tester,
        TaskCard(
          title: 'Site',
          status: '1h30 de 3h',
          controls: true,
          onMore: () => calls.add('more'),
          onDone: () => calls.add('done'),
          bar: const TaskBar(done: 0.5, time: 0.6),
        ),
      );

      await tester.tap(find.byTooltip(l10n.controlLess10));
      await tester.tap(find.byTooltip(l10n.controlMore10));
      await tester.tap(find.byTooltip(l10n.controlDone));
      expect(calls, ['more', 'done']);
      expect(find.text('1h30 de 3h'), findsOneWidget);
      expect(find.byType(TaskCardBar), findsOneWidget);
    });

    testWidgets('says a name once when its task is itself', (tester) async {
      await pump(
        tester,
        TaskCard(
          title: 'Notas fiscais',
          subtitle: ' notas fiscais ',
          onPlay: () {},
        ),
      );

      expect(find.textContaining('otas fiscais'), findsOneWidget);
    });

    testWidgets('keeps the button small, and its room for a fixed block', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          children: [
            TaskCard(title: 'Roteiro', onPlay: () {}),
            const TaskCard(title: 'Reunião', keepPlaySlot: true),
            const TaskCard(title: 'Almoço'),
          ],
        ),
      );

      expect(TaskPlayButton.size, 24);
      expect(tester.getSize(find.byType(TaskPlayButton)).width, 24);
      final left = tester.getTopLeft(find.text('Roteiro')).dx;
      expect(tester.getTopLeft(find.text('Reunião')).dx, left);
      expect(tester.getTopLeft(find.text('Almoço')).dx, lessThan(left));
    });

    testWidgets('puts its hours on the title line, not in the middle', (
      tester,
    ) async {
      await pump(
        tester,
        TaskCard(
          title: 'Post de novembro',
          subtitle: 'Roteiro',
          trailing: '10:00 – 10:45',
          onPlay: () {},
        ),
      );

      final title = tester.getRect(find.text('Post de novembro'));
      final hours = tester.getRect(find.text('10:00 – 10:45'));
      expect(
        hours.bottom,
        lessThan(tester.getTopLeft(find.text('Roteiro')).dy),
      );
      expect((hours.center.dy - title.center.dy).abs(), lessThan(4));
      expect(
        tester.getTopLeft(find.byType(TaskPlayButton)).dy,
        lessThan(tester.getTopLeft(find.text('Roteiro')).dy),
      );
    });
  });
}
