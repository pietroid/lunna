import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

/// Play's strict rules (#89): the room, the when question's three shapes,
/// the how-much table, and the pause.
void main() {
  /// Wednesday 28 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 28, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  setUpAll(() => registerFallbackValue(const TimelineRequested()));

  TimelineEvent card(
    String id, {
    int at = 0,
    int minutes = 45,
    CardKind kind = CardKind.task,
    bool started = false,
    TimelineSection section = TimelineSection.dia,
    String title = 'Tarefa',
  }) {
    final start = now.add(Duration(minutes: at));
    return TimelineEvent(
      id: id,
      title: title,
      section: section,
      kind: kind,
      started: started,
      startTime: start,
      endTime: start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
      workMinutes: minutes,
    );
  }

  group('playPieces', () {
    test('over an hour, with room for all of it: 30 min, 1h, the whole', () {
      expect(playPieces(owed: 240, room: 300), [30, 60, 240]);
    });

    test(
      'over an hour, with an hour or more of room: 30 min, 1h, the room',
      () {
        expect(playPieces(owed: 240, room: 133), [30, 60, 133]);
        expect(playPieces(owed: 240, room: 60), [30, 60]);
      },
    );

    test('over an hour, with under an hour of room: only the room', () {
      expect(playPieces(owed: 240, room: 40), [40]);
      expect(playPieces(owed: 240, room: 20), [20]);
    });

    test('an hour or less that fits asks nothing; that does not, the room', () {
      expect(playPieces(owed: 60, room: 60), isNull);
      expect(playPieces(owed: 45, room: 300), isNull);
      expect(playPieces(owed: 45, room: 20), [20]);
    });
  });

  group('the room', () {
    test('runs to the next thing that keeps its hour, less the pause', () {
      final day = TimelineState(
        cards: [
          card('q', at: 30), // queued: flows around, takes none
          card('m', at: 120, kind: CardKind.event, title: 'Standup'),
        ],
      );
      final room = playRoomAt(day, now);
      expect(room.minutes, 115);
      expect(room.until?.title, 'Standup');
      expect(room.untilLabel(l10n), l10n.playMuchUntil('Standup', '12:00'));
    });

    test('runs to the end of the working day when nothing is in the way', () {
      final room = playRoomAt(const TimelineState(), now);
      expect(room.minutes, 12 * 60);
      expect(room.until, isNull);
      expect(room.untilLabel(l10n), l10n.playMuchDayEnd('22:00'));
    });

    test('is none inside a block, and none with the pause left out', () {
      final running = card(
        'r',
        at: -10,
        started: true,
        section: TimelineSection.agora,
      );
      final day = TimelineState(cards: [running]);
      expect(playRoomAt(day, now).minutes, 0);
      expect(playRoomAt(day, now, pausing: true).minutes, 12 * 60);
    });

    test('skips an hour with under 20 minutes of room', () {
      // A gap of 15 minutes (10:00–10:15) before a meeting is not offered.
      final day = TimelineState(
        cards: [card('m', at: 20, minutes: 60, kind: CardKind.event)],
      );
      expect(playRoomAt(day, now).minutes, 15);
      expect(playFirstRoom(day, now), DateTime(2026, 10, 28, 11, 25));
    });
  });

  group('when', () {
    test('idle: now, and 15 minutes from now', () {
      final task = card('t', at: 30);
      final when = withClock(
        Clock.fixed(now),
        () => playWhenOf(TimelineState(cards: [task], tasks: [task]), task),
      );
      expect(when.canStartNow, isTrue);
      expect(when.later, PlayLater.soon);
      expect(when.laterAt, DateTime(2026, 10, 28, 10, 15));
      expect(when.running, isNull);
    });

    test('idle, 15 minutes from now without room: the first hour that has', () {
      final task = card('t', at: 200);
      final meeting = card('m', at: 30, minutes: 60, kind: CardKind.event);
      final when = withClock(
        Clock.fixed(now),
        () => playWhenOf(TimelineState(cards: [meeting, task]), task),
      );
      expect(when.canStartNow, isTrue);
      expect(when.later, PlayLater.at);
      expect(when.laterAt, DateTime(2026, 10, 28, 11, 35));
    });

    test('busy: now, and after what runs, unless it is next already', () {
      final running = card(
        'r',
        at: -10,
        started: true,
        section: TimelineSection.agora,
        title: 'Roteiro',
      );
      final next = card('n', at: 40);
      final last = card('l', at: 90);
      final day = TimelineState(
        cards: [running, next, last],
        tasks: [running, next, last],
      );
      final later = withClock(Clock.fixed(now), () => playWhenOf(day, last));
      expect(later.canStartNow, isTrue);
      expect(later.later, PlayLater.after);
      expect(later.laterAt, DateTime(2026, 10, 28, 10, 40));
      expect(later.running?.title, 'Roteiro');

      final first = withClock(Clock.fixed(now), () => playWhenOf(day, next));
      expect(first.later, isNull);
    });

    test('no Começar agora inside a fixed block, or 10 minutes before one', () {
      final block = card(
        'b',
        at: -10,
        kind: CardKind.event,
        section: TimelineSection.agora,
        started: true,
      );
      final task = card('t', at: 60);
      final inBlock = withClock(
        Clock.fixed(now),
        () => playWhenOf(TimelineState(cards: [block, task]), task),
      );
      expect(inBlock.canStartNow, isFalse);

      final meeting = card('m', at: 10, kind: CardKind.event);
      final before = withClock(
        Clock.fixed(now),
        () => playWhenOf(TimelineState(cards: [meeting, task]), task),
      );
      expect(before.canStartNow, isFalse);
    });
  });

  group('the sheets', () {
    late _MockTimelineBloc bloc;

    setUp(() => bloc = _MockTimelineBloc());

    Future<void> pump(WidgetTester tester, TimelineState day) async {
      when(() => bloc.state).thenReturn(day);
      await tester.pumpWidget(
        BlocProvider<TimelineBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.current,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    for (final c in day.cards)
                      if (c.isTask && !c.started)
                        TextButton(
                          onPressed: () => playTask(context, c),
                          child: Text('play ${c.id}'),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a short task begun with nothing running asks only when', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, TimelineState(cards: [card('t', at: 30)]));
        await tester.tap(find.text('play t'));
        await tester.pumpAndSettle();
        expect(find.byType(PauseQuestion), findsNothing);
        await tester.tap(find.text(l10n.playWhenNow));
        await tester.pumpAndSettle();
        expect(find.byType(PlayMuchQuestion), findsNothing);
        verify(
          () => bloc.add(const EventMoved(id: 't', index: 0, start: true)),
        ).called(1);
      });
    });

    testWidgets('with a task running: when, the pause, how much, then posts', (
      tester,
    ) async {
      final running = card(
        'r',
        at: -10,
        started: true,
        section: TimelineSection.agora,
        title: 'Roteiro',
      );
      final long = card('t', at: 40, minutes: 240, title: 'Escrever');
      final meeting = card(
        'm',
        at: 120,
        kind: CardKind.event,
        title: 'Standup',
      );
      await withClock(Clock.fixed(now), () async {
        await pump(
          tester,
          TimelineState(cards: [running, long, meeting], tasks: [running]),
        );
        await tester.tap(find.text('play t'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.playWhenNow));
        await tester.pumpAndSettle();

        // The pause, before how much: no means nothing changes.
        expect(find.text(l10n.guardPauseTitle('Roteiro')), findsOneWidget);
        await tester.tap(find.text(l10n.guardPauseYes));
        await tester.pumpAndSettle();

        // From now to the Standup, with Roteiro paused: 1h55.
        expect(find.text(l10n.playMuchNowTitle), findsOneWidget);
        expect(find.text('1h55'), findsOneWidget);
        await tester.tap(find.text('1h55'));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(
            const EventMoved(
              id: 't',
              index: 0,
              start: true,
              minutes: 115,
              decision: TimingDecision.pauseCurrent,
            ),
          ),
        ).called(1);
      });
    });

    testWidgets('no to the pause posts nothing', (tester) async {
      final running = card(
        'r',
        at: -10,
        started: true,
        section: TimelineSection.agora,
      );
      await withClock(Clock.fixed(now), () async {
        await pump(
          tester,
          TimelineState(cards: [running, card('t', at: 40)], tasks: [running]),
        );
        await tester.tap(find.text('play t'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.playWhenNow));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.guardPauseNo));
        await tester.pumpAndSettle();
        verifyNever(() => bloc.add(any()));
      });
    });

    testWidgets('a short task that does not fit offers only the room', (
      tester,
    ) async {
      final meeting = card('m', at: 40, kind: CardKind.event, title: 'Call');
      await withClock(Clock.fixed(now), () async {
        await pump(
          tester,
          TimelineState(cards: [meeting, card('t', at: 90, minutes: 50)]),
        );
        await tester.tap(find.text('play t'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.playWhenNow));
        await tester.pumpAndSettle();
        expect(find.text(l10n.playMuchDo('35 min')), findsOneWidget);
        await tester.tap(find.text(l10n.playMuchDo('35 min')));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(
            const EventMoved(id: 't', index: 0, start: true, minutes: 35),
          ),
        ).called(1);
      });
    });
  });
}
