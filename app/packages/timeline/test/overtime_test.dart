import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

void main() {
  /// Ten in the morning, wherever this runs.
  final now = DateTime(2026, 6, 10, 10);

  /// Relatório, begun at nine for an hour, in Agora; [over] minutes past
  /// its planned end with nobody saying it was over.
  TimelineEvent report({int over = 0}) => TimelineEvent(
    id: 'r',
    title: 'Relatório',
    section: TimelineSection.agora,
    startTime: now.subtract(const Duration(hours: 1)),
    // The server drags the end along with the clock while it runs on.
    endTime: now.add(const Duration(minutes: 1)),
    durationMinutes: 61,
    overtimeMinutes: over,
  );

  Future<void> pump(
    WidgetTester tester,
    TimelineEvent card, {
    List<String>? taps,
  }) async {
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
                  onPauseToggled: () => taps?.add('pause'),
                  onAdjusted: (minutes) => taps?.add('adjust $minutes'),
                  onDone: () => taps?.add('done'),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  test('reads how late a card is from the API, and nothing as on time', () {
    final late = TimelineEvent.fromJson(const {
      'id': 'r',
      'title': 'Relatório',
      'overtimeMinutes': 5,
    });
    final onTime = TimelineEvent.fromJson(const {
      'id': 'r',
      'title': 'Relatório',
    });

    expect(late.overtimeMinutes, 5);
    expect(late.isLate, isTrue);
    expect(onTime.isLate, isFalse);
  });

  testWidgets('late, says how late in place of the bar, and asks to close '
      'it: +10 on the left, Terminei on the right', (tester) async {
    final taps = <String>[];
    await pump(tester, report(over: 5), taps: taps);

    expect(find.text('Atraso no término · 5 minutos'), findsOneWidget);
    expect(find.byType(NowProgress), findsNothing);
    // Pause and −10 are left out: a late block is only closed.
    expect(find.text('−10'), findsNothing);

    final more = find.text('+10 min');
    final done = find.text('Terminei');
    expect(more, findsOneWidget);
    expect(done, findsOneWidget);
    expect(tester.getCenter(more).dx, lessThan(tester.getCenter(done).dx));

    await tester.tap(more);
    await tester.tap(done);
    expect(taps, ['adjust 10', 'done']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says one minute in the singular', (tester) async {
    await pump(tester, report(over: 1));

    expect(find.text('Atraso no término · 1 minuto'), findsOneWidget);
  });

  testWidgets('on time, keeps the bar and says nothing of a delay', (
    tester,
  ) async {
    await pump(tester, report());

    expect(find.byType(NowProgress), findsOneWidget);
    expect(find.textContaining('Atraso'), findsNothing);
    expect(find.text('Terminei'), findsNothing);
  });

  testWidgets('steps ten minutes either way', (tester) async {
    await pump(tester, report());

    expect(find.text('+10'), findsOneWidget);
    expect(find.text('−10'), findsOneWidget);
    expect(stepMinutes, 10);
  });
}
