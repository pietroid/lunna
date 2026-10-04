import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  final now = DateTime.now();
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
    section: TimelineSection.hoje,
    startTime: now.add(const Duration(minutes: 25)),
    endTime: now.add(const Duration(minutes: 55)),
    durationMinutes: 30,
  );

  TimelineEvent block(
    String id,
    int fromMinutes,
    int minutes, {
    TimelineSection section = TimelineSection.hoje,
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
    List<TimelineEvent> cards,
  ) async {
    final bloc = _MockTimelineBloc();
    when(() => bloc.state).thenReturn(
      TimelineState(status: TimelineStatus.success, cards: cards),
    );
    final tapped = <TimelineEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BlocProvider<TimelineBloc>.value(
            value: bloc,
            child: TimelineList(onCardTap: tapped.add),
          ),
        ),
      ),
    );
    await tester.pump();

    return (bloc as TimelineBloc, tapped);
  }

  testWidgets('a button on the running card is not a tap on the card', (
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

  testWidgets('takes fifteen minutes off only once it is confirmed', (
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

  testWidgets('a tap on the card itself still opens it', (tester) async {
    final (_, tapped) = await pump(tester, [running, later]);

    await tester.tap(find.text('Depois'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tapped.map((card) => card.id), ['b']);
  });

  testWidgets(
    'the break between two blocks is a free stretch, not an empty Agora',
    (tester) async {
      await pump(tester, [later]);

      expect(find.text('Agora'), findsOneWidget);
      // Now until the next block is the break. After it until ten, and all
      // of tomorrow, are empty room drawn to scale.
      expect(find.byType(FreeTile), findsOneWidget);
      expect(find.text('Nada programado'), findsOneWidget);
      // Only the one happening now is the break, and says so.
      final breakLines = FreeTile.messages.where(
        (line) => find.text(line).evaluate().isNotEmpty,
      );
      expect(breakLines, hasLength(1));

      expect(stretchFrom(later.endTime), findsOneWidget);
      // Tomorrow sits below a whole evening drawn to scale.
      await tester.scrollUntilVisible(find.text('Amanhã'), 400);
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 7);
      expect(stretchFrom(tomorrow), findsOneWidget);
    },
    // The stretch from now is only drawn inside the working day.
    skip: now.hour < 7 || now.hour >= 21,
  );

  testWidgets('every card says when it starts and when it ends', (
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

  testWidgets('a block whose hour came is the running card, paused at zero', (
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

  testWidgets('a routine is drawn with its mark and opens like any block', (
    tester,
  ) async {
    final lunch = TimelineEvent(
      id: 'lunch',
      title: 'Almoço',
      section: TimelineSection.hoje,
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

  testWidgets(
    'a card too long for the gap it is dropped in asks to be cut to fit',
    (tester) async {
      final first = TimelineEvent(
        id: 'x',
        title: 'Primeiro',
        section: TimelineSection.hoje,
        startTime: now.add(const Duration(minutes: 20)),
        endTime: now.add(const Duration(minutes: 50)),
        durationMinutes: 30,
      );
      final meeting = TimelineEvent(
        id: 'f',
        title: 'Reunião',
        section: TimelineSection.hoje,
        startTime: now.add(const Duration(minutes: 80)),
        endTime: now.add(const Duration(minutes: 110)),
        durationMinutes: 30,
        fixed: true,
      );
      final long = TimelineEvent(
        id: 'long',
        title: 'Longo',
        section: TimelineSection.hoje,
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
    skip: now.hour < 7 || now.hour >= 18,
  );

  testWidgets('an empty Agora is as tall as a running one', (tester) async {
    await pump(tester, [running]);
    final busy = tester.getSize(find.byType(EventTile)).height;

    await pump(tester, [later]);
    final empty = find.byType(FreeTile);

    expect(tester.getSize(empty).height, busy);
    // It is now, and the card after it says when now ends.
    expect(
      find.descendant(of: empty, matching: find.textContaining(':')),
      findsNothing,
    );
  });

  group('later in the day', () {
    // Everything here sits within the next three hours, so it stays inside
    // today's working day.
    final skip = now.hour < 7 || now.hour >= 19;

    testWidgets(
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
      skip: skip,
    );

    testWidgets(
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
      skip: skip,
    );

    testWidgets(
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
      skip: skip,
    );

    testWidgets(
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
      skip: skip,
    );
  });

  group('a drop', () {
    final skip = now.hour < 7 || now.hour >= 19;

    testWidgets(
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

        // Index 0 is the server's cue for the guard that asks.
        verify(() => bloc.add(const EventMoved(id: 'c', index: 0))).called(1);
      },
      skip: skip,
    );

    testWidgets(
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
      skip: skip,
    );

    testWidgets(
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
      skip: skip,
    );

    testWidgets(
      'a fixed card lands on the quarter it is let go on, drawn there first',
      (tester) async {
        final first = block('x', 25, 25);
        final pinned = TimelineEvent(
          id: 'p',
          title: 'Fixo',
          section: TimelineSection.hoje,
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

        verify(
          () => bloc.add(EventMoved(id: 'p', index: 2, after: expected)),
        ).called(1);
      },
      skip: skip,
    );

    testWidgets(
      'a fixed card let go between two cards stays where it was',
      (tester) async {
        final pinned = TimelineEvent(
          id: 'p',
          title: 'Fixo',
          section: TimelineSection.hoje,
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
      skip: skip,
    );
  });

  group('a tap on empty room', () {
    final skip = now.hour < 7 || now.hour >= 19;

    Future<(Finder, FreeSlot, List<FreeTap>)> pumpRoom(
      WidgetTester tester,
    ) async {
      final first = block('x', 25, 25);
      final last = block('y', 240, 25);
      final bloc = _MockTimelineBloc();
      when(() => bloc.state).thenReturn(
        TimelineState(
          status: TimelineStatus.success,
          cards: [running, first, last],
        ),
      );
      final taps = <FreeTap>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BlocProvider<TimelineBloc>.value(
              value: bloc,
              child: TimelineList(onCardTap: (_) {}, onFreeTap: taps.add),
            ),
          ),
        ),
      );
      await tester.pump();

      final gap = stretchFrom(first.endTime);
      return (gap, tester.widget<FreeStretch>(gap).slot, taps);
    }

    testWidgets(
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
            const Duration(minutes: TimelineScale.step);
        final dy = (soon ? lines[1] : lines[0]) / 2;

        await tester.tapAt(tester.getTopLeft(gap) + Offset(10, dy));
        await tester.pump(const Duration(milliseconds: 400));

        expect(taps, [(from: room.earliest, fixedAt: null)]);
      },
      skip: skip,
    );

    testWidgets(
      'on a later hour is something fixed at that hour',
      (tester) async {
        final (gap, room, taps) = await pumpRoom(tester);
        final lines = TimelineScale.hourLines(room);
        final from = room.earliest;
        final hour = DateTime(from.year, from.month, from.day, from.hour + 2);

        // Anywhere inside the hour after the second line, which is a part
        // of its own however soon the first line comes.
        await tester.tapAt(
          tester.getTopLeft(gap) + Offset(10, (lines[1] + lines[2]) / 2),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // The room's start comes along, for when the sheet is switched back
        // to flexible.
        expect(taps, [(from: room.earliest, fixedAt: hour)]);
      },
      skip: skip,
    );
  });
}
