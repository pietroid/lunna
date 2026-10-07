import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineRepository extends Mock implements TimelineRepository {}

DateTime _at(int hour, {int minute = 0, int addDays = 0}) {
  return DateTime(2026, 8, 27 + addDays, hour, minute);
}

TimelineEvent _card(
  String id, {
  required TimelineSection section,
  required DateTime start,
  int minutes = 30,
  CardKind kind = CardKind.task,
  bool managed = true,
  bool fixed = false,
}) {
  return TimelineEvent(
    id: id,
    title: id,
    section: section,
    kind: kind,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    managed: managed,
    fixed: fixed,
  );
}

/// A guard, as the server would send one.
final _guard = StartNowGuard(
  taskId: 'c',
  index: 0,
  currentId: 'a',
  currentTitle: 'a',
  currentStart: _at(9),
  currentEnd: _at(9, minute: 30),
);

/// The queue as the server sends it: what runs first, then the rest.
final _tasks = <TimelineEvent>[
  _card('a', section: TimelineSection.agora, start: _at(9)),
  _card('b', section: TimelineSection.dia, start: _at(14)),
  _card('c', section: TimelineSection.dia, start: _at(15)),
  _card('d', section: TimelineSection.dia, start: _at(9, addDays: 1)),
];

/// A fixed block, which only the calendar has.
final TimelineEvent _meeting = _card(
  'm',
  section: TimelineSection.dia,
  start: _at(11),
  kind: CardKind.event,
  fixed: true,
);

/// The day as the server sends it: the queue, and the calendar.
final _day = Timeline(tasks: _tasks, cards: [..._tasks, _meeting]);

/// A task in the backlog, as the server sends one: no hours.
TimelineEvent _shelved(String id) => TimelineEvent.fromJson({
  'id': id,
  'kind': 'task',
  'title': id,
  'section': 'backlog',
  'durationMinutes': 45,
  'workMinutes': 45,
  'notes': '',
});

/// The queue with [id] lifted out and put back at [index].
///
/// The real server also rewrites every hour the move disturbed. The order is
/// the part the bloc is responsible for drawing, so that is the part the
/// double bothers to get right.
Timeline _moved(String id, int index) {
  final tasks = [..._tasks];
  final task = tasks.removeAt(tasks.indexWhere((c) => c.id == id));
  tasks.insert(index.clamp(0, tasks.length), task);

  return Timeline(tasks: tasks, cards: [...tasks, _meeting]);
}

void main() {
  late TimelineRepository repository;

  setUp(() {
    repository = _MockTimelineRepository();
    when(
      () => repository.fetch(days: any(named: 'days')),
    ).thenAnswer((_) async => _day);
    when(
      () => repository.moveTask(
        any(),
        any(),
        start: any(named: 'start'),
        after: any(named: 'after'),
        minutes: any(named: 'minutes'),
        days: any(named: 'days'),
      ),
    ).thenAnswer(
      (invocation) async => _moved(
        invocation.positionalArguments[0] as String,
        invocation.positionalArguments[1] as int,
      ),
    );
    when(
      () => repository.finish(any(), any(), days: any(named: 'days')),
    ).thenAnswer((_) async => const Timeline());
  });

  setUpAll(() => registerFallbackValue(CardKind.task));

  TimelineBloc build() => TimelineBloc(repository: repository);

  List<String> order(TimelineState state) =>
      state.tasks.map((card) => card.id).toList();

  TimelineState loaded({StartNowGuard? guard}) => TimelineState(
    status: TimelineStatus.success,
    tasks: _day.tasks,
    cards: _day.cards,
    guard: guard,
  );

  group('TimelineBloc', () {
    blocTest<TimelineBloc, TimelineState>(
      'loads the list and the calendar, a week of it',
      build: build,
      act: (bloc) => bloc.add(const TimelineRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.cards, contains(_meeting));
        expect(bloc.state.status, TimelineStatus.success);
        verify(
          () => repository.fetch(days: TimelineState.initialDays),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'draws another week when the calendar reaches its end',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const TimelineExtended()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        const days = TimelineState.initialDays + TimelineState.daysPerPage;
        expect(bloc.state.days, days);
        expect(bloc.state.extending, isFalse);
        verify(() => repository.fetch(days: days)).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'asks for one more week at a time',
      build: build,
      seed: () => loaded().copyWith(extending: true),
      act: (bloc) => bloc.add(const TimelineExtended()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => repository.fetch(days: any(named: 'days')));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'keeps asking for as many days as are drawn',
      build: build,
      seed: () => loaded().copyWith(days: 21),
      act: (bloc) => bloc.add(const EventFinished('b')),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => repository.finish(CardKind.task, 'b', days: 21)).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'draws the order the server sends back after a drop',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 1)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'c', 'b', 'd']);
        verify(
          () => repository.moveTask('c', 1, days: TimelineState.initialDays),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'sends a drop into the backlog as a place in the backlog',
      build: () {
        when(
          () => repository.moveTask(
            any(),
            any(),
            backlog: any(named: 'backlog'),
            days: any(named: 'days'),
          ),
        ).thenAnswer(
          (_) async => Timeline(
            tasks: _tasks.where((c) => c.id != 'c').toList(),
            backlog: [_shelved('c'), _shelved('z')],
          ),
        );
        return build();
      },
      seed: loaded,
      act: (bloc) =>
          bloc.add(const EventMoved(id: 'c', index: 0, backlog: true)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'd']);
        expect(bloc.state.backlog.map((c) => c.id), ['c', 'z']);
        verify(
          () => repository.moveTask(
            'c',
            0,
            backlog: true,
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'moves a task out of the backlog like any other task',
      build: build,
      seed: () => loaded().copyWith(backlog: [_shelved('z')]),
      act: (bloc) => bloc.add(const EventMoved(id: 'z', index: 2)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => repository.moveTask('z', 2, days: TimelineState.initialDays),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'takes a finished task off the backlog before the server answers',
      build: build,
      seed: () => loaded().copyWith(backlog: [_shelved('z')]),
      act: (bloc) => bloc.add(const EventFinished('z')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(
          () => repository.finish(
            CardKind.task,
            'z',
            days: TimelineState.initialDays,
          ),
        ).called(1);
        expect(bloc.state.backlog, isEmpty);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'says when a drop was at the very top of the day',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0, start: true)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => repository.moveTask(
            'c',
            0,
            start: true,
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'leaves the timeline alone and raises the guard the move came back with',
      build: () {
        when(
          () => repository.moveTask(
            any(),
            any(),
            start: any(named: 'start'),
            days: any(named: 'days'),
          ),
        ).thenAnswer((_) async => Timeline(tasks: _tasks, guard: _guard));
        return build();
      },
      seed: loaded,
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0, start: true)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.guard, _guard);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'never moves an event as though it had a place in the queue',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const EventMoved(id: 'm', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(
          () => repository.moveTask(any(), any(), days: any(named: 'days')),
        );
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'answers a guard and draws what came back',
      build: () {
        when(
          () => repository.applyTiming(any(), days: any(named: 'days')),
        ).thenAnswer((_) async => _moved('c', 0));
        return build();
      },
      seed: () => loaded(guard: _guard),
      act: (bloc) => bloc.add(const GuardAnswered(TimingDecision.solveCurrent)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['c', 'a', 'b', 'd']);
        verify(
          () => repository.applyTiming({
            'taskId': 'c',
            'index': 0,
            'decision': 'solve_current',
          }, days: TimelineState.initialDays),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'dropping a guard changes nothing',
      build: build,
      seed: () => loaded(guard: _guard),
      act: (bloc) => bloc.add(const GuardDismissed()),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        verifyNever(
          () => repository.applyTiming(any(), days: any(named: 'days')),
        );
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'takes a finished card off both views before the write lands',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const EventFinished('b')),
      verify: (bloc) {
        expect(order(bloc.state), isNot(contains('b')));
        expect(bloc.state.cards.map((it) => it.id), isNot(contains('b')));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'finishes an event where events are kept',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const EventFinished('m')),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => repository.finish(
            CardKind.event,
            'm',
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'puts a finished card back when the write fails',
      build: () {
        when(
          () => repository.finish(any(), any(), days: any(named: 'days')),
        ).thenThrow(Exception('nope'));
        return build();
      },
      seed: loaded,
      act: (bloc) => bloc.add(const EventFinished('b')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.status, TimelineStatus.failure);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'takes a deleted card off at once, and puts it back on a refusal',
      build: () {
        when(
          () => repository.delete(any(), any(), days: any(named: 'days')),
        ).thenThrow(Exception('nope'));
        return build();
      },
      seed: loaded,
      act: (bloc) => bloc.add(const EventDeleted('b')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TimelineState>().having(order, 'order', ['a', 'c', 'd']),
        isA<TimelineState>()
            .having(order, 'order', ['a', 'b', 'c', 'd'])
            .having((s) => s.status, 'status', TimelineStatus.failure),
      ],
    );

    blocTest<TimelineBloc, TimelineState>(
      'keeps the sentence the server refused in',
      build: () {
        when(
          () => repository.createTask(
            title: any(named: 'title'),
            minutes: any(named: 'minutes'),
            days: any(named: 'days'),
          ),
        ).thenThrow(const TimelineFailure('A agenda não respondeu.'));
        return build();
      },
      act: (bloc) => bloc.add(
        const EventCreated(
          title: 'Revisar proposta',
          durationMinutes: 30,
          fixed: false,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.failure?.message, 'A agenda não respondeu.');
        expect(bloc.state.status, TimelineStatus.failure);
        expect(bloc.state.tasks, isEmpty);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'writes something flexible down as a task',
      build: () {
        when(
          () => repository.createTask(
            title: any(named: 'title'),
            minutes: any(named: 'minutes'),
            days: any(named: 'days'),
          ),
        ).thenAnswer((_) async => _day);
        return build();
      },
      act: (bloc) => bloc.add(
        const EventCreated(
          title: 'Revisar proposta',
          durationMinutes: 30,
          fixed: false,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.status, TimelineStatus.success);
        verify(
          () => repository.createTask(
            title: 'Revisar proposta',
            minutes: 30,
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'writes something fixed down as an event at its hour',
      build: () {
        when(
          () => repository.createEvent(
            title: any(named: 'title'),
            durationMinutes: any(named: 'durationMinutes'),
            startTime: any(named: 'startTime'),
            days: any(named: 'days'),
          ),
        ).thenAnswer((_) async => _day);
        return build();
      },
      act: (bloc) => bloc.add(
        EventCreated(
          title: 'Reunião',
          durationMinutes: 30,
          fixed: true,
          startTime: _at(16),
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => repository.createEvent(
            title: 'Reunião',
            durationMinutes: 30,
            startTime: _at(16),
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'pauses a running card and draws it paused before the server answers',
      build: () {
        when(
          () => repository.pause(any(), any(), days: any(named: 'days')),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _day;
        });
        return build();
      },
      seed: loaded,
      act: (bloc) => bloc.add(const EventPauseToggled('a')),
      wait: const Duration(milliseconds: 5),
      verify: (bloc) {
        expect(bloc.state.byId('a')!.isPaused, isTrue);
        verify(
          () => repository.pause(
            CardKind.task,
            'a',
            days: TimelineState.initialDays,
          ),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'resumes a paused card with the same button',
      build: () {
        when(
          () => repository.resume(any(), any(), days: any(named: 'days')),
        ).thenAnswer((_) async => _day);
        return build();
      },
      seed: () => loaded().copyWith(
        tasks: [
          _tasks.first.copyWith(pausedAt: _at(9, minute: 10)),
          ..._tasks.skip(1),
        ],
      ),
      act: (bloc) => bloc.add(const EventPauseToggled('a')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(
          () => repository.resume(
            CardKind.task,
            'a',
            days: TimelineState.initialDays,
          ),
        ).called(1);
        expect(bloc.state.byId('a')!.isPaused, isFalse);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'gives fifteen more minutes and draws the day that comes back',
      build: () {
        when(
          () =>
              repository.extend(any(), any(), any(), days: any(named: 'days')),
        ).thenAnswer(
          (_) async => Timeline(tasks: _tasks.reversed.toList()),
        );
        return build();
      },
      seed: loaded,
      act: (bloc) => bloc.add(const EventExtended('a')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(
          () => repository.extend(
            CardKind.task,
            'a',
            15,
            days: TimelineState.initialDays,
          ),
        ).called(1);
        expect(order(bloc.state), ['d', 'c', 'b', 'a']);
      },
    );
  });

  blocTest<TimelineBloc, TimelineState>(
    'saves notes where the card is kept',
    setUp: () {
      when(
        () => repository.edit(
          any(),
          any(),
          notes: any(named: 'notes'),
          days: any(named: 'days'),
        ),
      ).thenAnswer((_) async => _day);
    },
    build: () => TimelineBloc(repository: repository),
    seed: loaded,
    act: (bloc) => bloc
      ..add(const EventEdited('a', notes: 'Seção 3.'))
      ..add(const EventEdited('m', notes: 'Sala 2.')),
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(
        () => repository.edit(
          CardKind.task,
          'a',
          notes: 'Seção 3.',
          days: TimelineState.initialDays,
        ),
      ).called(1);
      verify(
        () => repository.edit(
          CardKind.event,
          'm',
          notes: 'Sala 2.',
          days: TimelineState.initialDays,
        ),
      ).called(1);
    },
  );

  group('TimelinePlan', () {
    test('takes the hour asked for when the day is empty', () {
      final start = TimelinePlan.nextFreeStart(
        const [],
        const Duration(minutes: 30),
        now: _at(9, minute: 12),
      );

      expect(start, _at(9, minute: 12));
    });

    test('steps over what is already booked, keeping the gap', () {
      final start = TimelinePlan.nextFreeStart(
        [
          _card(
            'a',
            section: TimelineSection.agora,
            start: _at(9),
            minutes: 60,
          ),
        ],
        const Duration(minutes: 30),
        now: _at(9, minute: 30),
      );

      expect(start, _at(10, minute: 5));
    });

    test('fills a gap rather than queueing at the end', () {
      final start = TimelinePlan.nextFreeStart(
        [
          _card('a', section: TimelineSection.agora, start: _at(9)),
          _card('b', section: TimelineSection.dia, start: _at(14)),
        ],
        const Duration(minutes: 30),
        now: _at(9),
      );

      expect(start, _at(9, minute: 35));
    });

    test('puts a new task after the last one in the queue', () {
      final start = TimelinePlan.nextQueuedStart(
        [_meeting],
        [
          _card('a', section: TimelineSection.agora, start: _at(9)),
          _card('b', section: TimelineSection.dia, start: _at(14)),
        ],
        const Duration(minutes: 30),
        now: _at(9),
      );

      expect(start, _at(14, minute: 35));
    });

    test('spills into the next day rather than past the end of this one', () {
      final start = TimelinePlan.nextFreeStart(
        const [],
        const Duration(minutes: 60),
        now: _at(21, minute: 30),
      );

      expect(start, _at(7, addDays: 1));
    });
  });

  group('TimelineEvent', () {
    final card = _card('a', section: TimelineSection.agora, start: _at(9));

    test('reads a task the server sent, with its day', () {
      final read = TimelineEvent.fromJson(const {
        'id': 'a',
        'kind': 'task',
        'title': 'a',
        'section': 'dia',
        'day': '2026-10-08',
        'startTime': '2026-10-08T12:00:00.000Z',
        'endTime': '2026-10-08T12:30:00.000Z',
        'durationMinutes': 30,
        'started': false,
      });

      expect(read.isTask, isTrue);
      expect(read.isAnchored, isFalse);
      expect(read.section, TimelineSection.dia);
      expect(read.day, DateTime(2026, 10, 8));
    });

    test('reads an event as having its own hour', () {
      final read = TimelineEvent.fromJson(const {
        'id': 'm',
        'kind': 'event',
        'title': 'm',
        'section': 'dia',
        'startTime': '2026-10-08T12:00:00.000Z',
        'endTime': '2026-10-08T12:30:00.000Z',
        'durationMinutes': 30,
        'fixed': true,
      });

      expect(read.isTask, isFalse);
      expect(read.isAnchored, isTrue);
    });

    test('is barely started one minute into a block the server sent', () {
      final now = DateTime.now();
      final started = TimelineEvent.fromJson({
        'id': 'a',
        'title': 'a',
        'section': 'agora',
        'startTime': now
            .subtract(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String(),
        'endTime': now
            .add(const Duration(minutes: 29))
            .toUtc()
            .toIso8601String(),
        'durationMinutes': 30,
        'workMinutes': 30,
        'pausedSeconds': 0,
      });

      expect(started.progressAt(now), closeTo(1 / 30, 0.001));
    });

    test('fills with the clock while it runs', () {
      expect(card.progressAt(_at(9, minute: 15)), 0.5);
    });

    test('stands still while paused, and skips the time spent paused', () {
      final paused = TimelineEvent(
        id: 'a',
        title: 'a',
        section: TimelineSection.agora,
        startTime: _at(9),
        endTime: _at(9, minute: 50),
        durationMinutes: 50,
        workMinutes: 30,
        pausedSeconds: 10 * 60,
        pausedAt: _at(9, minute: 25),
      );

      expect(paused.progressAt(_at(9, minute: 40)), 0.5);
    });
  });

  group('a task waiting to be begun', () {
    blocTest<TimelineBloc, TimelineState>(
      'is drawn as begun before the server answers',
      setUp: () {
        when(
          () => repository.startTask(any(), days: any(named: 'days')),
        ).thenAnswer((_) async => _day);
      },
      build: () => TimelineBloc(repository: repository),
      seed: () => TimelineState(
        status: TimelineStatus.success,
        tasks: [
          TimelineEvent(
            id: 'a',
            title: 'a',
            section: TimelineSection.agora,
            startTime: _at(9),
            endTime: _at(9, minute: 30),
            durationMinutes: 30,
            awaitingStart: true,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const EventStarted('a')),
      verify: (bloc) {
        verify(
          () => repository.startTask('a', days: TimelineState.initialDays),
        ).called(1);
        expect(bloc.state.tasks, _tasks);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'is asked about even before the day has loaded',
      setUp: () {
        when(
          () => repository.snoozeTask(
            any(),
            minutes: any(named: 'minutes'),
            days: any(named: 'days'),
          ),
        ).thenAnswer((_) async => _day);
      },
      build: () => TimelineBloc(repository: repository),
      act: (bloc) => bloc.add(const EventSnoozed('a')),
      verify: (_) {
        verify(
          () => repository.snoozeTask('a', days: TimelineState.initialDays),
        ).called(1);
      },
    );
  });

  blocTest<TimelineBloc, TimelineState>(
    'a drop into a gap sends where the gap starts and the cut length',
    build: () => TimelineBloc(repository: repository),
    seed: loaded,
    act: (bloc) => bloc.add(
      EventMoved(id: 'c', index: 1, after: _at(11), minutes: 20),
    ),
    verify: (_) {
      verify(
        () => repository.moveTask(
          'c',
          1,
          after: _at(11),
          minutes: 20,
          days: TimelineState.initialDays,
        ),
      ).called(1);
    },
  );
}
