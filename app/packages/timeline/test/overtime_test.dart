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

  Future<void> pump(WidgetTester tester, TimelineEvent card) async {
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
                  onPauseToggled: () {},
                  onAdjusted: (_) {},
                  onDone: () {},
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

  testWidgets('says "atrasado" on Agora while it runs past its end', (
    tester,
  ) async {
    await pump(tester, report(over: 5));

    expect(find.text('atrasado 5 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says nothing while it is on time', (tester) async {
    await pump(tester, report());

    expect(find.textContaining('atrasado'), findsNothing);
  });

  testWidgets('steps ten minutes either way', (tester) async {
    await pump(tester, report());

    expect(find.text('+10'), findsOneWidget);
    expect(find.text('−10'), findsOneWidget);
    expect(stepMinutes, 10);
  });
}
