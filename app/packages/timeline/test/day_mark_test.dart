import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

TimelineEvent _card(String id, DateTime start, int minutes) {
  return TimelineEvent(
    id: id,
    title: id,
    section: TimelineSection.dia,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    kind: CardKind.event,
  );
}

void main() {
  group('DayMark', () {
    test('reads what the server says of a day', () {
      final mark = DayMark.fromJson({
        'day': '2026-10-29',
        'kind': 'light',
        'reason': 'period',
        'budgetMinutes': 180,
        'cycle': {'day': 2, 'length': 28, 'phase': 'menstrual'},
      });

      expect(
        mark,
        DayMark(
          day: DateTime(2026, 10, 29),
          kind: DayKind.light,
          reason: DayReason.period,
          budgetMinutes: 180,
          cycleDay: 2,
          cycleLength: 28,
          phase: CyclePhase.menstrual,
        ),
      );
      expect(mark.restricted, isTrue);
    });

    test(
      'reads a day off with no cycle, and a kind it does not know as work',
      () {
        final off = DayMark.fromJson({
          'day': '2026-10-31',
          'kind': 'off',
          'reason': 'weekend',
        });
        expect(off.kind, DayKind.off);
        expect(off.reason, DayReason.weekend);
        expect(off.phase, isNull);
        expect(
          DayMark.fromJson({'day': '2026-11-02', 'kind': '?'}).kind,
          DayKind.work,
        );
      },
    );

    test('a timeline carries its days', () {
      final timeline = Timeline.fromJson({
        'tasks': <dynamic>[],
        'backlog': <dynamic>[],
        'cards': <dynamic>[],
        'workDay': {'start': '07:00', 'end': '22:00'},
        'days': [
          {'day': '2026-10-31', 'kind': 'off', 'reason': 'weekend'},
        ],
      });
      expect(timeline.marks.on(DateTime(2026, 10, 31, 15))?.kind, DayKind.off);
      expect(timeline.marks.on(DateTime(2026, 11)), isNull);
    });
  });

  group('free stretches on a day off', () {
    // Friday 30 October 2026, nine at night; the weekend is off.
    final now = DateTime(2026, 10, 30, 21);
    final saturday = DayMark(
      day: DateTime(2026, 10, 31),
      kind: DayKind.off,
      reason: DayReason.weekend,
    );

    test('an empty one is one rest row', () {
      final slots = TimelinePlan.freeSlots(
        const [],
        now: now,
        days: 2,
        marks: [saturday],
      );

      final rest = slots.where((it) => it.start.day == 31).single;
      expect(rest.rest, saturday);
      expect(rest.start, DateTime(2026, 10, 31, 7));
    });

    test('one with a fixed block has no room at all', () {
      final slots = TimelinePlan.freeSlots(
        [_card('Aniversário', DateTime(2026, 10, 31, 15), 120)],
        now: now,
        days: 2,
        marks: [saturday],
      );

      expect(slots.where((it) => it.start.day == 31), isEmpty);
    });
  });

  testWidgets(
    'the heading’s tag says a light day, and the rest row offers work',
    (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt', 'BR'),
          home: Scaffold(
            body: Column(
              children: [
                DayMarkTag(
                  mark: DayMark(
                    day: DateTime(2026, 10, 29),
                    kind: DayKind.light,
                    reason: DayReason.period,
                    budgetMinutes: 180,
                    cycleDay: 2,
                    cycleLength: 28,
                    phase: CyclePhase.menstrual,
                  ),
                ),
                RestDayTile(
                  mark: DayMark(
                    day: DateTime(2026, 10, 31),
                    kind: DayKind.off,
                    reason: DayReason.weekend,
                  ),
                  onWork: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(l10n.dayLightTag('3h')), findsOneWidget);
      expect(find.text(l10n.dayOffWeekend), findsOneWidget);
      expect(find.text(l10n.dayOffWorkHere), findsOneWidget);
    },
  );
}
