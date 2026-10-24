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

/// Lets a sheet open or close. Not `pumpAndSettle`: the running card's light
/// goes round forever, so the screen never settles.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

String hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() => registerFallbackValue(const TimelineRequested()));

  /// Ten in the morning, on the wall clock of whatever machine runs this.
  ///
  /// The screen reads the hour off [clock], and every test here runs with
  /// it stopped at this instant. Read off the real clock, the same suite
  /// drew a different day in every zone it ran in: in UTC on CI at six in
  /// the evening the room to the end of the day had two hours in it rather
  /// than three, and at three in the morning in Tokyo half of it skipped
  /// itself. June, so no zone is changing its offset that day.
  final now = DateTime(2026, 6, 10, 10);

  /// [testWidgets], with the clock stopped at [now].
  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  final running = TimelineEvent(
    id: 'a',
    title: 'Escrever',
    section: TimelineSection.agora,
    startTime: now.subtract(const Duration(minutes: 10)),
    endTime: now.add(const Duration(minutes: 20)),
    durationMinutes: 30,
  );
  final later = TimelineEvent(
    id: 'b',
    title: 'Depois',
    section: TimelineSection.dia,
    startTime: now.add(const Duration(minutes: 25)),
    endTime: now.add(const Duration(minutes: 55)),
    durationMinutes: 30,
  );

  TimelineEvent block(
    String id,
    int fromMinutes,
    int minutes, {
    TimelineSection section = TimelineSection.dia,
  }) {
    return TimelineEvent(
      id: id,
      title: 'Bloco $id',
      section: section,
      startTime: now.add(Duration(minutes: fromMinutes)),
      endTime: now.add(Duration(minutes: fromMinutes + minutes)),
      durationMinutes: minutes,
    );
  }

  Finder stretchFrom(DateTime start) => find.byWidgetPredicate(
    (widget) => widget is FreeStretch && widget.slot.start == start,
  );

  /// Picks up the card titled [title] and lets it go at height [y], straight
  /// up or down, as a reorder is.
  Future<void> drag(WidgetTester tester, String title, double y) async {
    final from = tester.getCenter(find.text(title));
    final target = Offset(from.dx, y);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 350));
    for (var step = 1; step <= 8; step++) {
      await gesture.moveTo(Offset.lerp(from, target, step / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  Future<(TimelineBloc, List<TimelineEvent>)> pump(
    WidgetTester tester,
    List<TimelineEvent> cards, {
    TimelineMode mode = TimelineMode.calendar,
    TimelineState? state,
  }) async {
    final bloc = _MockTimelineBloc();
    when(() => bloc.state).thenReturn(
      state ??
          TimelineState(
            status: TimelineStatus.success,
            cards: cards,
            tasks: cards.where((card) => card.isTask).toList(),
          ),
    );
    final tapped = <TimelineEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.current,
        home: Scaffold(
          body: BlocProvider<TimelineBloc>.value(
            value: bloc,
            child: TimelineList(onCardTap: tapped.add, mode: mode),
          ),
        ),
      ),
    );
    await tester.pump();

    return (bloc as TimelineBloc, tapped);
  }

  testAt('a button on the running card is not a tap on the card', (
    tester,
  ) async {
    final (bloc, tapped) = await pump(tester, [running, later]);

    await tester.tap(find.byIcon(AppIcons.pause.iconData!));
    await tester.pump(const Duration(milliseconds: 400));

    verify(() => bloc.add(const EventPauseToggled('a'))).called(1);
    expect(tapped, isEmpty);

    await tester.tap(find.text('+15'));
    await settle(tester);
    expect(tapped, isEmpty);
    // Changing the length moves the rest of the day, so it asks first.
    verifyNever(() => bloc.add(const EventExtended('a')));
    expect(find.text('Mais 15 minutos?'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await settle(tester);
    verify(() => bloc.add(const EventExtended('a'))).called(1);
  });

  testAt('takes fifteen minutes off only once it is confirmed', (
    tester,
  ) async {
    final (bloc, _) = await pump(tester, [running, later]);

    await tester.tap(find.text('−15'));
    await settle(tester);
    expect(find.text('Menos 15 minutos?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    verifyNever(() => bloc.add(any()));

    await tester.tap(find.text('−15'));
    await settle(tester);
    await tester.tap(find.text('Tirar'));
    await settle(tester);
    verify(() => bloc.add(const EventExtended('a', minutes: -15))).called(1);
  });

  testAt('a tap on the card itself still opens it', (tester) async {
    final (_, tapped) = await pump(tester, [running, later]);

    await tester.tap(find.text('Depois'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tapped.map((card) => card.id), ['b']);
  });

  testAt(
    'the break between two blocks is a free stretch, not an empty Agora',
    (tester) async {
      await pump(tester, [later]);

      expect(find.text('Agora'), findsOneWidget);
      // Now until the next block is the break. After it until ten, and all
      // of tomorrow, are empty room drawn to scale.
      expect(find.byType(FreeTile), findsOneWidget);
      expect(find.text('Nada programado'), findsOneWidget);
      // Only the one happening now is the break, and says so.
      final breakLines =
          FreeTile.messages(
            lookupAppLocalizations(const Locale('pt')),
          ).where(
            (line) => find.text(line).evaluate().isNotEmpty,
          );
      expect(breakLines, hasLength(1));

      expect(stretchFrom(later.endTime), findsOneWidget);
      // Tomorrow sits below a whole evening drawn to scale.
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 7);
      // To the room itself, not only to the heading over it: a heading at the
      // bottom edge leaves what is under it offstage.
      await tester.scrollUntilVisible(stretchFrom(tomorrow), 400);
      expect(find.text('Amanhã'), findsOneWidget);
    },
  );

  testAt('every card says when it starts and when it ends', (
    tester,
  ) async {
    await pump(tester, [running, later]);

    for (final card in [running, later]) {
      final tile = find.widgetWithText(EventTile, card.title);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            '${hhmm(card.startTime)}–${hhmm(card.endTime)}',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testAt('a block whose hour came is the running card, paused at zero', (
    tester,
  ) async {
    final waiting = TimelineEvent(
      id: 'w',
      title: 'Esperando',
      section: TimelineSection.agora,
      startTime: now,
      endTime: now.add(const Duration(minutes: 30)),
      durationMinutes: 30,
      awaitingStart: true,
    );
    final (bloc, tapped) = await pump(tester, [waiting]);

    // The same card as a running block, stopped before its first minute.
    expect(find.text('Pausado · faltam 30 min'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0);
    // Nothing is running yet, so there is nothing to pause.
    expect(find.byIcon(AppIcons.pause.iconData!), findsNothing);

    await tester.tap(find.byIcon(AppIcons.play.iconData!));
    await tester.pump(const Duration(milliseconds: 400));
    verify(() => bloc.add(const EventStarted('w'))).called(1);

    // Fifteen more minutes before it asks, not fifteen more minutes of work.
    await tester.tap(find.text('+15'));
    await tester.pump(const Duration(milliseconds: 400));
    verify(() => bloc.add(const EventSnoozed('w'))).called(1);
    expect(find.text('Mais 15 minutos?'), findsNothing);
    expect(tapped, isEmpty);
  });

  testAt('a routine is drawn with its mark and opens like any block', (
    tester,
  ) async {
    final lunch = TimelineEvent(
      id: 'lunch',
      title: 'Almoço',
      section: TimelineSection.dia,
      kind: CardKind.event,
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      durationMinutes: 60,
      fixed: true,
      routine: 'daily',
    );
    final (_, tapped) = await pump(tester, [lunch]);

    expect(find.byIcon(AppIcons.repeat.iconData!), findsOneWidget);

    // This day of it is edited from here; the routine as a whole is not.
    await tester.tap(find.text('Almoço'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped, [lunch]);
  });

  testAt(
    'a card too long for the gap it is dropped in asks to be cut to fit',
    (tester) async {
      final first = TimelineEvent(
        id: 'x',
        title: 'Primeiro',
        section: TimelineSection.dia,
        startTime: now.add(const Duration(minutes: 20)),
        endTime: now.add(const Duration(minutes: 50)),
        durationMinutes: 30,
      );
      final meeting = TimelineEvent(
        id: 'f',
        title: 'Reunião',
        section: TimelineSection.dia,
        kind: CardKind.event,
        startTime: now.add(const Duration(minutes: 80)),
        endTime: now.add(const Duration(minutes: 110)),
        durationMinutes: 30,
        fixed: true,
      );
      final long = TimelineEvent(
        id: 'long',
        title: 'Longo',
        section: TimelineSection.dia,
        startTime: now.add(const Duration(minutes: 115)),
        endTime: now.add(const Duration(minutes: 175)),
        durationMinutes: 60,
      );
      final (bloc, _) = await pump(tester, [first, meeting, long]);

      final gap = stretchFrom(first.endTime);
      expect(gap, findsOneWidget);

      await drag(tester, 'Longo', tester.getCenter(gap).dy);

      // Twenty-five minutes of room: the gap less the pause after "Primeiro".
      expect(find.text('Não cabe inteiro aqui'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<EventMoved>())));

      await tester.tap(find.text('Ajustar para 25 min'));
      await settle(tester);

      verify(
        () => bloc.add(
          EventMoved(
            id: 'long',
            index: 1,
            after: first.endTime.add(const Duration(minutes: 5)),
            minutes: 25,
          ),
        ),
      ).called(1);
    },
  );

  testAt(
    'an empty Agora is as tall as a running one',
    (tester) async {
      await pump(tester, [running]);
      final busy = tester.getSize(find.byType(EventTile)).height;

      await pump(tester, [later]);
      final empty = find.byType(FreeTile);

      expect(tester.getSize(empty).height, busy);
      // It is now, and the card after it says when now ends.
      // An hour, not any colon: some of the break's lines have one.
      expect(
        find.descendant(
          of: empty,
          matching: find.textContaining(RegExp(r'\d{1,2}:\d{2}')),
        ),
        findsNothing,
      );
    },
  );

  group('later in the day', () {
    testAt(
      'a card is as tall as its time, and never shorter than half an hour',
      (tester) async {
        await pump(tester, [
          running,
          block('half', 25, 25),
          block('hour', 55, 55),
          block('short', 115, 10),
        ]);

        double height(String id) =>
            tester.getSize(find.widgetWithText(EventTile, 'Bloco $id')).height;

        // 25 and its pause is exactly one card, 55 and its pause two.
        expect(height('half'), TimelineScale.halfHour - AppSpacing.s1);
        expect(height('hour'), 2 * TimelineScale.halfHour - AppSpacing.s1);
        expect(height('short'), height('half'));
      },
    );

    testAt(
      'empty room is drawn only past ten minutes, and the pause never',
      (tester) async {
        final next = block('next', 25, 30);
        final close = block('close', 68, 30);
        final far = block('far', 140, 30);
        await pump(tester, [running, next, close, far]);

        // Hoje starts at the block after the running one: the five minutes
        // between them are the pause.
        expect(stretchFrom(running.endTime), findsNothing);
        // Thirteen minutes, eight of room once the pause is taken out.
        expect(stretchFrom(next.endTime), findsNothing);

        final gap = stretchFrom(close.endTime);
        expect(gap, findsOneWidget);
        expect(
          find.descendant(
            of: gap,
            matching: find.text(
              '${hhmm(close.endTime)}–${hhmm(far.startTime)}',
            ),
          ),
          findsOneWidget,
        );
        // Thirty-seven minutes of room, drawn to scale.
        expect(
          tester.getSize(gap).height,
          closeTo(37 * TimelineScale.perMinute - AppSpacing.s1, 0.01),
        );
      },
    );

    testAt(
      'with nothing running, the room from now opens Hoje too',
      (tester) async {
        final next = block('next', 60, 30);
        final (bloc, _) = await pump(tester, [next]);

        final from = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        );
        // The break under Agora is still there, as it was.
        expect(find.byType(FreeTile), findsOneWidget);
        final gap = stretchFrom(from);
        expect(gap, findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Ainda hoje')).dy,
          lessThan(tester.getTopLeft(gap).dy),
        );
        expect(
          tester.getTopLeft(gap).dy,
          lessThan(tester.getTopLeft(find.text('Bloco next')).dy),
        );

        // And it is somewhere to drop, like the break it repeats.
        await drag(tester, 'Bloco next', tester.getTopLeft(gap).dy + 10);
        verify(
          () => bloc.add(EventMoved(id: 'next', index: 0, after: from)),
        ).called(1);
      },
    );

    testAt(
      'room between the running block and the next opens Hoje',
      (tester) async {
        await pump(tester, [running, block('next', 60, 30)]);

        final gap = stretchFrom(running.endTime);
        expect(gap, findsOneWidget);
        expect(
          tester.getTopLeft(gap).dy,
          lessThan(tester.getTopLeft(find.text('Bloco next')).dy),
        );
      },
    );
  });

  group('a drop', () {
    testAt(
      'on the running block asks to start it now',
      (tester) async {
        final (bloc, _) = await pump(tester, [
          running,
          later,
          block('c', 60, 25),
        ]);

        final top = tester.getTopLeft(
          find.widgetWithText(EventTile, 'Escrever'),
        );
        await drag(tester, 'Bloco c', top.dy + 4);

        // The very top of the day is doing it now, which is the server's cue
        // for the guard that asks.
        verify(
          () => bloc.add(const EventMoved(id: 'c', index: 0, start: true)),
        ).called(1);
      },
    );

    testAt(
      'between the running block and the next one reorders',
      (tester) async {
        final (bloc, _) = await pump(tester, [
          running,
          later,
          block('c', 60, 25),
        ]);

        final above = tester.getBottomLeft(
          find.widgetWithText(EventTile, 'Escrever'),
        );
        final below = tester.getTopLeft(
          find.widgetWithText(EventTile, 'Depois'),
        );
        await drag(tester, 'Bloco c', (above.dy + below.dy) / 2);

        verify(() => bloc.add(const EventMoved(id: 'c', index: 1))).called(1);
      },
    );

    testAt(
      'anywhere in empty room lands at the start of it',
      (tester) async {
        final first = block('x', 25, 25);
        final last = block('y', 180, 25);
        final (bloc, _) = await pump(tester, [running, first, last]);

        // Near the top of a long stretch, far from its middle.
        final gap = stretchFrom(first.endTime);
        await drag(tester, 'Bloco y', tester.getTopLeft(gap).dy + 10);

        verify(
          () => bloc.add(
            EventMoved(
              id: 'y',
              index: 2,
              after: first.endTime.add(const Duration(minutes: 5)),
            ),
          ),
        ).called(1);
      },
    );

    testAt(
      'a fixed card lands on the quarter it is let go on, drawn there first',
      (tester) async {
        final first = block('x', 25, 25);
        final pinned = TimelineEvent(
          id: 'p',
          title: 'Fixo',
          section: TimelineSection.dia,
          kind: CardKind.event,
          startTime: now.add(const Duration(minutes: 200)),
          endTime: now.add(const Duration(minutes: 230)),
          durationMinutes: 30,
          fixed: true,
        );
        final (bloc, _) = await pump(tester, [running, first, pinned]);

        final gap = stretchFrom(first.endTime);
        final room = tester.widget<FreeStretch>(gap).slot;
        final top = tester.getTopLeft(gap).dy;
        final height = tester.getSize(gap).height;
        // An hour and a bit into the room, which is not on a quarter.
        final aimedAt = room.earliest.add(const Duration(minutes: 68));
        final dy = TimelineScale.offsetOf(room, aimedAt, height);

        final card = find.widgetWithText(EventTile, 'Fixo');
        final from = tester.getCenter(card);
        final grab = from.dy - tester.getTopLeft(card).dy;
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 350));
        final to = Offset(from.dx, top + dy + grab);
        for (var step = 1; step <= 8; step++) {
          await gesture.moveTo(Offset.lerp(from, to, step / 8)!);
          await tester.pump(const Duration(milliseconds: 16));
        }

        final expected = TimelineScale.landingIn(room, aimedAt, 30);
        expect(expected.minute % TimelineScale.step, 0);
        final preview = tester.widget<FreeStretch>(gap).preview;
        expect(preview?.start, expected);
        expect(preview?.end, expected.add(const Duration(minutes: 30)));

        await gesture.up();
        await settle(tester);

        // An event has an hour rather than a place, so the drop names one.
        verify(() => bloc.add(EventEdited('p', startTime: expected))).called(1);
      },
    );

    testAt(
      'a fixed card let go between two cards stays where it was',
      (tester) async {
        final pinned = TimelineEvent(
          id: 'p',
          title: 'Fixo',
          section: TimelineSection.dia,
          kind: CardKind.event,
          startTime: now.add(const Duration(minutes: 90)),
          endTime: now.add(const Duration(minutes: 120)),
          durationMinutes: 30,
          fixed: true,
        );
        final (bloc, _) = await pump(tester, [running, later, pinned]);

        final above = tester.getBottomLeft(
          find.widgetWithText(EventTile, 'Escrever'),
        );
        final below = tester.getTopLeft(
          find.widgetWithText(EventTile, 'Depois'),
        );
        await drag(tester, 'Fixo', (above.dy + below.dy) / 2);

        verifyNever(() => bloc.add(any(that: isA<EventMoved>())));
      },
    );

    testAt(
      'counts only the tasks above it, not the events',
      (tester) async {
        final meeting = TimelineEvent(
          id: 'm',
          title: 'Reunião',
          section: TimelineSection.dia,
          kind: CardKind.event,
          startTime: now.add(const Duration(minutes: 60)),
          endTime: now.add(const Duration(minutes: 90)),
          durationMinutes: 30,
          fixed: true,
        );
        final (bloc, _) = await pump(tester, [
          running,
          later,
          meeting,
          block('c', 95, 25),
          block('d', 125, 25),
        ]);

        // Between the meeting and "Bloco c": the fourth place on the
        // calendar, and the third in the queue. Right under a meeting,
        // which has an hour rather than a place, it asks for the hour after.
        final above = tester.getBottomLeft(
          find.widgetWithText(EventTile, 'Reunião'),
        );
        final below = tester.getTopLeft(
          find.widgetWithText(EventTile, 'Bloco c'),
        );
        await drag(tester, 'Bloco d', (above.dy + below.dy) / 2);

        verify(
          () => bloc.add(
            EventMoved(
              id: 'd',
              index: 2,
              after: meeting.endTime.add(TimelinePlan.gap),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('the list', () {
    final meeting = TimelineEvent(
      id: 'm',
      title: 'Reunião',
      section: TimelineSection.dia,
      kind: CardKind.event,
      startTime: now.add(const Duration(minutes: 60)),
      endTime: now.add(const Duration(minutes: 90)),
      durationMinutes: 30,
      fixed: true,
    );

    testAt('has the tasks and nothing else', (tester) async {
      await pump(tester, [
        running,
        later,
        meeting,
      ], mode: TimelineMode.list);

      expect(find.text('Escrever'), findsOneWidget);
      expect(find.text('Depois'), findsOneWidget);
      expect(find.text('Reunião'), findsNothing);
      expect(find.byType(FreeStretch), findsNothing);
      expect(find.byType(FreeTile), findsNothing);
    });

    testAt('draws every task as tall as it needs', (tester) async {
      await pump(tester, [
        running,
        block('short', 30, 10),
        block('long', 45, 120),
      ], mode: TimelineMode.list);

      double height(String id) =>
          tester.getSize(find.widgetWithText(EventTile, 'Bloco $id')).height;

      expect(height('long'), height('short'));
    });

    testAt('keeps one day, under Agora, and counts what is later', (
      tester,
    ) async {
      final inTwoDays = DateTime(now.year, now.month, now.day + 2, 9);
      final far = TimelineEvent(
        id: 'far',
        title: 'Longe',
        section: TimelineSection.dia,
        startTime: inTwoDays,
        endTime: inTwoDays.add(const Duration(minutes: 30)),
        durationMinutes: 30,
      );
      await pump(tester, [running, far], mode: TimelineMode.list);

      final l10n = lookupAppLocalizations(const Locale('pt'));
      // Nothing else today: the day kept is tomorrow, and the task two
      // days out is only counted.
      expect(find.text(l10n.sectionNow), findsOneWidget);
      expect(find.text(l10n.sectionTomorrow), findsOneWidget);
      expect(find.text('Longe'), findsNothing);
      expect(
        find.text(
          '${l10n.stageAhead(1)} · ${l10n.stageAheadOpen}',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testAt('reorders the queue by its place in the list', (tester) async {
      final (bloc, _) = await pump(tester, [
        running,
        later,
        block('c', 60, 25),
      ], mode: TimelineMode.list);

      final above = tester.getBottomLeft(
        find.widgetWithText(EventTile, 'Escrever'),
      );
      final below = tester.getTopLeft(find.widgetWithText(EventTile, 'Depois'));
      await drag(tester, 'Bloco c', (above.dy + below.dy) / 2);

      verify(() => bloc.add(const EventMoved(id: 'c', index: 1))).called(1);
    });

    testAt('starts what is dropped above what is running', (
      tester,
    ) async {
      final (bloc, _) = await pump(tester, [
        running,
        later,
      ], mode: TimelineMode.list);

      final top = tester.getTopLeft(find.widgetWithText(EventTile, 'Escrever'));
      await drag(tester, 'Depois', top.dy + 4);

      verify(
        () => bloc.add(const EventMoved(id: 'b', index: 0, start: true)),
      ).called(1);
    });

    testAt('always draws both stages, saying when each is empty', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      await pump(tester, [meeting], mode: TimelineMode.list);

      expect(find.text(l10n.sectionToday), findsOneWidget);
      expect(find.text(l10n.stageDayEmpty), findsOneWidget);
      expect(find.text(l10n.stageBacklog), findsOneWidget);
      expect(find.text(l10n.stageBacklogEmpty), findsOneWidget);
    });

    /// A task in the backlog, as the server sends one: a length, no hours.
    TimelineEvent shelved(String id, String title) => TimelineEvent.fromJson({
      'id': id,
      'kind': 'task',
      'title': title,
      'section': 'backlog',
      'durationMinutes': 45,
      'workMinutes': 45,
    });

    /// The list with [tasks] in the queue and [backlog] below it.
    Future<TimelineBloc> pumpStages(
      WidgetTester tester,
      List<TimelineEvent> tasks,
      List<TimelineEvent> backlog,
    ) async {
      final (bloc, _) = await pump(
        tester,
        tasks,
        mode: TimelineMode.list,
        state: TimelineState(
          status: TimelineStatus.success,
          cards: tasks,
          tasks: tasks,
          backlog: backlog,
        ),
      );
      return bloc;
    }

    testAt('draws the backlog under the queue, with lengths for hours', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      await pumpStages(tester, [running], [shelved('x', 'Armário')]);

      final line = tester.getTopLeft(find.text(l10n.stageBacklog)).dy;
      expect(tester.getTopLeft(find.text('Escrever')).dy, lessThan(line));
      expect(tester.getTopLeft(find.text('Armário')).dy, greaterThan(line));
      expect(find.text(l10n.durationMinutes(45)), findsOneWidget);
    });

    testAt('drags a task from the queue into the backlog', (tester) async {
      final bloc = await pumpStages(
        tester,
        [running, later],
        [shelved('x', 'Armário'), shelved('y', 'Gaveta')],
      );

      final above = tester.getBottomLeft(
        find.widgetWithText(EventTile, 'Armário'),
      );
      final below = tester.getTopLeft(find.widgetWithText(EventTile, 'Gaveta'));
      await drag(tester, 'Depois', (above.dy + below.dy) / 2);

      verify(
        () => bloc.add(const EventMoved(id: 'b', index: 1, backlog: true)),
      ).called(1);
    });

    testAt('drags a task from the backlog into the queue', (tester) async {
      final bloc = await pumpStages(
        tester,
        [running, later],
        [shelved('x', 'Armário')],
      );

      final above = tester.getBottomLeft(
        find.widgetWithText(EventTile, 'Escrever'),
      );
      final below = tester.getTopLeft(find.widgetWithText(EventTile, 'Depois'));
      await drag(tester, 'Armário', (above.dy + below.dy) / 2);

      verify(() => bloc.add(const EventMoved(id: 'x', index: 1))).called(1);
    });

    testAt('tells the end of the queue from the top of the backlog', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final bloc = await pumpStages(
        tester,
        [running, later],
        [shelved('x', 'Armário')],
      );

      final line = tester.getRect(find.text(l10n.stageBacklog));
      await drag(tester, 'Escrever', line.top - 24);
      verify(() => bloc.add(const EventMoved(id: 'a', index: 1))).called(1);

      final card = tester.getRect(find.widgetWithText(EventTile, 'Armário'));
      await drag(tester, 'Escrever', card.top + 2);
      verify(
        () => bloc.add(const EventMoved(id: 'a', index: 0, backlog: true)),
      ).called(1);
    });

    testAt('puts a task into an empty queue without starting it', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final bloc = await pumpStages(tester, [], [shelved('x', 'Armário')]);

      final empty = tester.getCenter(find.text(l10n.stageDayEmpty));
      await drag(tester, 'Armário', empty.dy);

      verify(() => bloc.add(const EventMoved(id: 'x', index: 0))).called(1);
    });

    testAt('drops into an empty backlog', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final bloc = await pumpStages(tester, [running, later], []);

      final empty = tester.getCenter(find.text(l10n.stageBacklogEmpty));
      await drag(tester, 'Depois', empty.dy + 8);

      verify(
        () => bloc.add(const EventMoved(id: 'b', index: 0, backlog: true)),
      ).called(1);
    });
  });

  group('a short drag on the calendar', () {
    /// Picks up [title], carries it [dy] down (or up), and holds it there
    /// for a look before [release] lets it go.
    Future<TestGesture> carry(
      WidgetTester tester,
      Offset from,
      double dy,
    ) async {
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 350));
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(from + Offset(0, dy * step / 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200));
      return gesture;
    }

    testAt('slides the task in time, and the task snapped to it along', (
      tester,
    ) async {
      final snapped = block('c', 60, 25);
      final (bloc, _) = await pump(tester, [running, later, snapped]);

      final gesture = await carry(
        tester,
        tester.getCenter(find.text('Depois')),
        20 * TimelineScale.perMinute,
      );

      // Nothing opens up: the card says where it goes, and the one snapped
      // to it reads its new hours.
      final at = later.startTime.add(const Duration(minutes: 20));
      expect(find.text('+20 min · ${hhmm(at)}'), findsOneWidget);
      final moved = snapped.startTime.add(const Duration(minutes: 20));
      expect(find.textContaining(hhmm(moved)), findsWidgets);

      await gesture.up();
      await settle(tester);

      verify(() => bloc.add(const EventShifted('b', 20))).called(1);
      verifyNever(() => bloc.add(any(that: isA<EventMoved>())));
    });

    testAt('slides it earlier too', (tester) async {
      final (bloc, _) = await pump(tester, [running, block('c', 120, 25)]);

      final gesture = await carry(
        tester,
        tester.getCenter(find.text('Bloco c')),
        -15 * TimelineScale.perMinute,
      );
      await gesture.up();
      await settle(tester);

      verify(() => bloc.add(const EventShifted('c', -15))).called(1);
    });

    testAt('let go on another task far away, trades places with it', (
      tester,
    ) async {
      final far = block('d', 150, 25);
      final (bloc, _) = await pump(tester, [
        running,
        later,
        block('c', 60, 25),
        far,
      ]);

      final gesture = await carry(
        tester,
        tester.getCenter(find.text('Bloco d')),
        tester.getCenter(find.text('Depois')).dy -
            tester.getCenter(find.text('Bloco d')).dy,
      );

      // Nothing opens up: the task under the finger reads the hour it would
      // trade for, and the card in the air reads its.
      expect(find.text('Trocar com Depois'), findsOneWidget);
      expect(find.textContaining(hhmm(far.startTime)), findsWidgets);

      await gesture.up();
      await settle(tester);

      verify(() => bloc.add(const EventSwapped('d', 'b'))).called(1);
      verifyNever(() => bloc.add(any(that: isA<EventMoved>())));
    });

    testAt('pulls the seam under a card, which gives it a new length', (
      tester,
    ) async {
      final (bloc, _) = await pump(tester, [
        running,
        later,
        block('c', 60, 25),
      ]);

      final card = tester.getRect(find.widgetWithText(EventTile, 'Depois'));
      final gesture = await carry(
        tester,
        Offset(card.center.dx, card.bottom - 4),
        15 * TimelineScale.perMinute,
      );

      expect(find.byType(SeamHandle), findsOneWidget);
      final end = later.endTime.add(const Duration(minutes: 15));
      expect(find.text('+15 min · até ${hhmm(end)}'), findsOneWidget);

      await gesture.up();
      await settle(tester);

      verify(() => bloc.add(const EventResized('b', 45))).called(1);
    });

    testAt('leaves Agora free while the running block is carried off it', (
      tester,
    ) async {
      final begun = TimelineEvent(
        id: 'a',
        title: 'Escrever',
        section: TimelineSection.agora,
        started: true,
        startTime: running.startTime,
        endTime: running.endTime,
        durationMinutes: 30,
      );
      final (bloc, _) = await pump(tester, [
        begun,
        later,
        block('c', 60, 25),
      ]);

      final gesture = await carry(
        tester,
        tester.getCenter(find.text('Escrever')),
        tester.getCenter(find.text('Bloco c')).dy -
            tester.getCenter(find.text('Escrever')).dy,
      );

      expect(find.text('Agora fica livre'), findsOneWidget);
      expect(find.textContaining('Pausar · volta com 20 min'), findsOneWidget);

      await gesture.up();
      await settle(tester);

      verify(
        () => bloc.add(
          any(that: isA<EventMoved>().having((it) => it.id, 'id', 'a')),
        ),
      ).called(1);
    });
  });

  group('late at night', () {
    final night = DateTime(2026, 6, 10, 21);
    final tomorrow = DateTime(2026, 6, 11, 7);

    TimelineEvent at(String id, DateTime start, int minutes) => TimelineEvent(
      id: id,
      title: 'Bloco $id',
      section: TimelineSection.dia,
      startTime: start,
      endTime: start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
    );

    testWidgets('a drop at the top of tomorrow asks for its first hour', (
      tester,
    ) async {
      await withClock(Clock.fixed(night), () async {
        final tonight = at('n', night.add(const Duration(minutes: 5)), 20);
        final first = at('t', tomorrow, 30);
        final second = at('u', tomorrow.add(const Duration(minutes: 35)), 30);
        final cards = [tonight, first, second];
        final (bloc, _) = await pump(
          tester,
          const [],
          state: TimelineState(
            status: TimelineStatus.success,
            cards: cards,
            tasks: cards,
            days: 2,
          ),
        );

        // On the heading: on the card itself would trade places with it.
        final heading = tester.getCenter(find.text('Amanhã'));
        await drag(tester, 'Bloco u', heading.dy);

        verify(
          () => bloc.add(EventMoved(id: 'u', index: 1, after: tomorrow)),
        ).called(1);
      });
    });

    testWidgets('the last card of today goes to the top of tomorrow', (
      tester,
    ) async {
      await withClock(Clock.fixed(night), () async {
        final tonight = at('n', night.add(const Duration(minutes: 5)), 20);
        final first = at('t', tomorrow, 30);
        final cards = [tonight, first];
        final (bloc, _) = await pump(
          tester,
          const [],
          state: TimelineState(
            status: TimelineStatus.success,
            cards: cards,
            tasks: cards,
            days: 2,
          ),
        );

        // Its place in the list does not change, and its day does: this
        // used to be taken for a card put back where it was.
        final heading = tester.getCenter(find.text('Amanhã'));
        await drag(tester, 'Bloco n', heading.dy);

        verify(
          () => bloc.add(EventMoved(id: 'n', index: 0, after: tomorrow)),
        ).called(1);
      });
    });

    testWidgets('Agora says the day is over, and begins nothing', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 6, 10, 22, 30)), () async {
        final first = at('t', tomorrow, 30);
        final (bloc, _) = await pump(
          tester,
          const [],
          state: TimelineState(
            status: TimelineStatus.success,
            cards: [first],
            tasks: [first],
            days: 2,
          ),
        );

        expect(find.byType(DayOverTile), findsOneWidget);
        expect(find.text('Seu dia terminou às 22:00'), findsOneWidget);

        final tile = tester.getCenter(find.byType(DayOverTile));
        await drag(tester, 'Bloco t', tile.dy);

        verifyNever(
          () => bloc.add(
            any(
              that: isA<EventMoved>().having((it) => it.start, 'start', true),
            ),
          ),
        );
      });
    });
  });

  group('the calendar', () {
    testAt('heads a day past tomorrow with its weekday and date', (
      tester,
    ) async {
      final inThreeDays = DateTime(now.year, now.month, now.day + 3, 9);
      final far = TimelineEvent(
        id: 'far',
        title: 'Longe',
        section: TimelineSection.dia,
        startTime: inThreeDays,
        endTime: inThreeDays.add(const Duration(minutes: 30)),
        durationMinutes: 30,
      );
      await pump(
        tester,
        const [],
        state: TimelineState(
          status: TimelineStatus.success,
          cards: [far],
          tasks: [far],
          days: 4,
        ),
      );

      final date = lookupAppLocalizations(
        const Locale('pt'),
      ).sectionDay(inThreeDays);
      final heading = find.text(date[0].toUpperCase() + date.substring(1));

      // To the heading, not to the card: two hours of empty room sit between
      // them, and a card at the bottom edge leaves its heading offstage.
      await tester.scrollUntilVisible(heading, 600);
      expect(heading, findsOneWidget);
    });

    testAt('asks for another week once scrolled to its end', (
      tester,
    ) async {
      final (bloc, _) = await pump(tester, [running, later]);

      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pump();

      verify(() => bloc.add(const TimelineExtended())).called(greaterThan(0));
    });

    testAt('never asks for more of the list', (tester) async {
      final (bloc, _) = await pump(tester, [
        for (var n = 0; n < 30; n++) block('$n', 30 * n, 25),
      ], mode: TimelineMode.list);

      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pump();

      verifyNever(() => bloc.add(const TimelineExtended()));
    });
  });

  group('a tap on empty room', () {
    Future<(Finder, FreeSlot, List<Placement>)> pumpRoom(
      WidgetTester tester,
    ) async {
      final first = block('x', 25, 25);
      final last = block('y', 240, 25);
      final bloc = _MockTimelineBloc();
      when(() => bloc.state).thenReturn(
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, first, last],
          tasks: [running, first, last],
        ),
      );
      final taps = <Placement>[];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.current,
          home: Scaffold(
            body: BlocProvider<TimelineBloc>.value(
              value: bloc,
              child: TimelineList(onCardTap: (_) {}, onWriteDown: taps.add),
            ),
          ),
        ),
      );
      await tester.pump();

      final gap = stretchFrom(first.endTime);
      return (gap, tester.widget<FreeStretch>(gap).slot, taps);
    }

    testAt(
      'on the room is something flexible from where the room starts',
      (tester) async {
        final (gap, room, taps) = await pumpRoom(tester);
        final lines = TimelineScale.hourLines(room);
        // Before the first full hour, or before the second when the first
        // comes too soon to be a part of its own.
        final soon =
            DateTime(
              room.earliest.year,
              room.earliest.month,
              room.earliest.day,
              room.earliest.hour + 1,
            ).difference(room.earliest) <
            const Duration(minutes: 15);
        final dy = (soon ? lines[1] : lines[0]) / 2;

        // Clear of the + at the left edge, which writes at the same hour.
        await tester.tapAt(tester.getTopLeft(gap) + Offset(200, dy));
        await tester.pump(const Duration(milliseconds: 400));

        expect(taps, [Placement.at(room.earliest)]);
      },
    );

    testAt(
      'on a later hour is something flexible at that hour',
      (tester) async {
        final (gap, room, taps) = await pumpRoom(tester);
        final lines = TimelineScale.hourLines(room);
        final from = room.earliest;
        final hour = DateTime(from.year, from.month, from.day, from.hour + 2);

        // Anywhere inside the hour after the second line, which is a part
        // of its own however soon the first line comes.
        await tester.tapAt(
          tester.getTopLeft(gap) + Offset(200, (lines[1] + lines[2]) / 2),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(taps, [Placement.at(hour)]);
      },
    );
  });

  group('always in sight', () {
    /// The list, with somewhere for what it writes down and aims at to go.
    Future<(TimelineBloc, List<Placement>, TimelineAim)> pumpWith(
      WidgetTester tester,
      TimelineState state, {
      TimelineMode mode = TimelineMode.calendar,
    }) async {
      final bloc = _MockTimelineBloc();
      when(() => bloc.state).thenReturn(state);
      final written = <Placement>[];
      final aim = TimelineAim();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.current,
          home: Scaffold(
            body: BlocProvider<TimelineBloc>.value(
              value: bloc,
              child: TimelineList(
                onCardTap: (_) {},
                onWriteDown: written.add,
                aim: aim,
                mode: mode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      return (bloc as TimelineBloc, written, aim);
    }

    testAt('Agora is drawn even when the next block is moments away', (
      tester,
    ) async {
      final soon = block('s', 3, 30);
      await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [soon],
          tasks: [soon],
        ),
      );

      expect(find.text('Agora'), findsOneWidget);
      expect(
        find.byWidgetPredicate((it) => it is FreeTile && it.now),
        findsOneWidget,
      );
    });

    testAt('a task let go on the break is begun now', (tester) async {
      final next = block('n', 60, 30);
      final (bloc, _, _) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [next],
          tasks: [next],
        ),
      );

      final room = find.byWidgetPredicate((it) => it is FreeTile && it.now);
      await drag(tester, 'Bloco n', tester.getCenter(room).dy);

      verify(
        () => bloc.add(const EventMoved(id: 'n', index: 0, start: true)),
      ).called(1);
    });

    testAt('the button at the foot aims at the first free hour in sight', (
      tester,
    ) async {
      final next = block('n', 60, 30);
      final (_, _, aim) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, next],
          tasks: [running, next],
        ),
      );

      // The room after the running block, a pause after it ends.
      expect(aim.value, Placement.at(running.endTime.add(TimelinePlan.gap)));
    });

    testAt('a stretch carries a + that writes there, filling short room', (
      tester,
    ) async {
      final next = block('n', 60, 30);
      final (_, written, _) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, next],
          tasks: [running, next],
        ),
      );

      final plus = find.byIcon(AppIcons.plus.iconData!);
      expect(plus, findsWidgets);
      await tester.tap(plus.first);
      await tester.pump(const Duration(milliseconds: 400));

      // The room up to the next block is short, so it is all of it.
      expect(written, [
        Placement.at(running.endTime.add(TimelinePlan.gap), minutes: 30),
      ]);
    });

    testAt('the + stays at the top of a stretch scrolled under it', (
      tester,
    ) async {
      final next = block('n', 600, 30);
      await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, next],
          tasks: [running, next],
        ),
      );
      final gap = find.byWidgetPredicate(
        (widget) =>
            widget is FreeStretch && widget.slot.start == running.endTime,
      );
      final plus = find.descendant(
        of: gap,
        matching: find.byIcon(AppIcons.plus.iconData!),
      );
      final list = tester.getRect(find.byType(ListView));

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(tester.getRect(gap).top, lessThan(list.top));
      final at = tester.getRect(plus).top;
      expect(at, greaterThan(list.top + 40));
      expect(at, lessThan(list.top + 40 + AppSpacing.tapTarget));

      // And moves with the next scroll in the same frame.
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();
      expect(tester.getRect(plus).top, moreOrLessEquals(at, epsilon: 0.5));

      // The hours stay beside it, from the first in sight.
      await tester.pump();
      final hours = find.descendant(
        of: gap,
        matching: find.textContaining('–${hhmm(next.startTime)}'),
      );
      expect(hours, findsOneWidget);
      expect(
        tester.widget<Text>(hours).data,
        isNot(startsWith(hhmm(running.endTime))),
      );
      expect(
        tester.getCenter(hours).dy,
        moreOrLessEquals(tester.getCenter(plus).dy, epsilon: 1),
      );
    });

    testAt('far down the day, a chip goes back to Agora', (tester) async {
      final (_, _, _) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running],
          tasks: [running],
        ),
      );
      final back = find.text('Agora');
      expect(back, findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump();

      // The heading scrolled away and the chip took its word.
      final chip = find.byIcon(AppIcons.arrowUp.iconData!);
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.controller!.offset, 0);
    });

    testAt('a card held near the bottom carries the list down', (
      tester,
    ) async {
      final next = block('n', 30, 30);
      await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [next],
          tasks: [next],
        ),
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      final bottom = tester.getBottomLeft(find.byType(ListView)).dy;

      final from = tester.getCenter(find.text('Bloco n'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 350));
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(
          Offset.lerp(from, Offset(from.dx, bottom - 10), step / 8)!,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(list.controller!.offset, greaterThan(0));
      await gesture.up();
      await settle(tester);
    });

    testAt('each stage of the list ends in a + that writes in it', (
      tester,
    ) async {
      final tomorrow = TimelineEvent(
        id: 't',
        title: 'Amanhã cedo',
        section: TimelineSection.dia,
        startTime: DateTime(2026, 6, 11, 8),
        endTime: DateTime(2026, 6, 11, 8, 30),
        durationMinutes: 30,
      );
      final (_, written, _) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, later, tomorrow],
          tasks: [running, later, tomorrow],
        ),
        mode: TimelineMode.list,
      );

      // The day kept ends in one, after its last task: tomorrow's is
      // only counted.
      final adds = find.text('Adicionar');
      expect(adds, findsNWidgets(2));
      await tester.tap(adds.first);
      await tester.pump(const Duration(milliseconds: 400));

      // So does the backlog, further down.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      await tester.tap(adds.last);
      await tester.pump(const Duration(milliseconds: 400));

      expect(written, [const Placement.queue(2), const Placement.backlog()]);
    });

    testAt('in the list, the button at the foot writes at the end of the '
        'stage at the top', (tester) async {
      final (_, _, aim) = await pumpWith(
        tester,
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, later],
          tasks: [running, later],
        ),
        mode: TimelineMode.list,
      );

      // The day kept is at the top: after the last task in it.
      expect(aim.value, const Placement.queue(2));
    });
  });

  group('kept to some tasks, as an artifact draws it', () {
    TimelineEvent shelved(String id, String title) => TimelineEvent.fromJson({
      'id': id,
      'kind': 'task',
      'title': title,
      'section': 'backlog',
      'durationMinutes': 30,
      'workMinutes': 30,
    });

    final queue = [block('x', 30, 30), block('c', 65, 30), block('y', 100, 30)];
    final backlog = [shelved('d', 'Textos'), shelved('z', 'Gaveta')];
    final finished = TimelineEvent(
      id: 'e',
      title: 'Logo',
      section: TimelineSection.backlog,
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.subtract(const Duration(hours: 1)),
      durationMinutes: 45,
    );

    Future<(TimelineBloc, List<TimelineEvent>)> pumpKept(
      WidgetTester tester,
    ) async {
      final bloc = _MockTimelineBloc();
      when(() => bloc.state).thenReturn(
        TimelineState(
          status: TimelineStatus.success,
          cards: queue,
          tasks: queue,
          backlog: backlog,
        ),
      );
      final tapped = <TimelineEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.current,
          home: Scaffold(
            body: BlocProvider<TimelineBloc>.value(
              value: bloc,
              child: TimelineList(
                onCardTap: tapped.add,
                mode: TimelineMode.list,
                only: const {'c', 'd'},
                done: [finished],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      return (bloc as TimelineBloc, tapped);
    }

    testAt('draws only those, and what was done under them', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final (_, tapped) = await pumpKept(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(find.text('Bloco x'), findsNothing);
      expect(find.text('Gaveta'), findsNothing);
      expect(top(l10n.stageSoon), lessThan(top('Bloco c')));
      expect(top('Bloco c'), lessThan(top(l10n.stageBacklog)));
      expect(top(l10n.stageBacklog), lessThan(top('Textos')));
      expect(top('Textos'), lessThan(top(l10n.stageDone(1))));
      expect(top(l10n.stageDone(1)), lessThan(top('Logo')));

      await tester.tap(find.text('Logo'));
      expect(tapped.single.id, 'e');
    });

    testAt('counts a drop in the whole queue, right over the card under it', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final (bloc, _) = await pumpKept(tester);

      final heading = tester.getBottomLeft(find.text(l10n.stageSoon)).dy;
      final card = tester.getTopLeft(find.widgetWithText(EventTile, 'Bloco c'));
      await drag(tester, 'Textos', (heading + card.dy) / 2);

      verify(() => bloc.add(const EventMoved(id: 'd', index: 1))).called(1);
    });

    testAt('counts a drop in the whole backlog, right under the card above', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      final (bloc, _) = await pumpKept(tester);

      final card = tester.getBottomLeft(
        find.widgetWithText(EventTile, 'Textos'),
      );
      final done = tester.getTopLeft(find.text(l10n.stageDone(1))).dy;
      await drag(tester, 'Bloco c', (card.dy + done) / 2);

      verify(
        () => bloc.add(const EventMoved(id: 'c', index: 1, backlog: true)),
      ).called(1);
    });
  });
}
