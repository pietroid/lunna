import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Agora on the calendar plays as Plano does: the round button before the
/// title, and the quiet row keeps −10, +10 and ✓.
void main() {
  /// Ten in the morning, wherever this runs.
  final now = DateTime(2026, 6, 10, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  TimelineEvent agora({
    CardKind kind = CardKind.task,
    bool started = true,
    bool awaiting = false,
    int over = 0,
  }) => TimelineEvent(
    id: 'r',
    title: 'Relatório',
    section: TimelineSection.agora,
    kind: kind,
    started: started,
    awaitingStart: awaiting,
    startTime: now.subtract(const Duration(minutes: 20)),
    endTime: now.add(const Duration(minutes: 40)),
    durationMinutes: 60,
    workMinutes: 60,
    overtimeMinutes: over,
  );

  Future<List<String>> pump(WidgetTester tester, TimelineEvent card) async {
    final taps = <String>[];
    await withClock(Clock.fixed(now), () async {
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
                width: 360,
                child: EventTile(
                  card: card,
                  onPauseToggled: () => taps.add('pause'),
                  onStarted: () => taps.add('start'),
                  onAdjusted: (minutes) => taps.add('adjust $minutes'),
                  onDone: () => taps.add('done'),
                ),
              ),
            ),
          ),
        ),
      );
    });
    return taps;
  }

  testWidgets('a running task pauses from the round button before its title', (
    tester,
  ) async {
    final taps = await pump(tester, agora());

    final button = find.byType(TaskPlayButton);
    expect(button, findsOneWidget);
    expect(tester.widget<TaskPlayButton>(button).playing, isTrue);
    expect(
      tester.getTopLeft(button).dx,
      lessThan(tester.getTopLeft(find.text('Relatório')).dx),
    );
    // The row keeps −10, +10 and ✓, and no pause of its own.
    expect(find.byTooltip(l10n.controlPause), findsOneWidget);
    expect(find.byTooltip(l10n.controlDone), findsOneWidget);

    await tester.tap(button);
    expect(taps, ['pause']);
  });

  testWidgets('a task waiting to be begun begins from it', (tester) async {
    final taps = await pump(tester, agora(started: false, awaiting: true));

    expect(
      tester.widget<TaskPlayButton>(find.byType(TaskPlayButton)).playing,
      isFalse,
    );
    await tester.tap(find.byType(TaskPlayButton));
    expect(taps, ['start']);
  });

  testWidgets('an event keeps its quiet row, with no round button', (
    tester,
  ) async {
    await pump(tester, agora(kind: CardKind.event));

    expect(find.byType(TaskPlayButton), findsNothing);
  });

  testWidgets('in overtime there is only closing it', (tester) async {
    await pump(tester, agora(over: 5));

    expect(find.byType(TaskPlayButton), findsNothing);
  });

  testWidgets('TaskCard draws a mark in the play’s room, titles in line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Column(
            children: [
              TaskCard(title: 'Roteiro', onPlay: () {}),
              const TaskCard(
                title: 'Standup',
                mark: AppIcons.pin,
                markInk: AppColors.fixedInk,
              ),
            ],
          ),
        ),
      ),
    );

    final pin = find.byWidgetPredicate(
      (w) => w is AppIcon && w.iconData == AppIcons.pin,
    );
    expect(pin, findsOneWidget);
    expect(tester.widget<AppIcon>(pin).color, AppColors.fixedInk);
    expect(
      tester.getTopLeft(find.text('Standup')).dx,
      tester.getTopLeft(find.text('Roteiro')).dx,
    );
  });
}
