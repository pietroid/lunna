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
  bool managed = true,
  bool fixed = false,
}) {
  return TimelineEvent(
    id: id,
    title: id,
    section: section,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    managed: managed,
    fixed: fixed,
  );
}

/// A guard, as the server would send one.
final _guard = StartNowGuard(
  eventId: 'c',
  index: 0,
  currentId: 'a',
  currentTitle: 'a',
  currentStart: _at(9),
  currentEnd: _at(9, minute: 30),
);

/// The day as the server sends it: one flat list, in clock order.
final _cards = <TimelineEvent>[
  _card('a', section: TimelineSection.agora, start: _at(9)),
  _card('b', section: TimelineSection.hoje, start: _at(14)),
  _card('c', section: TimelineSection.hoje, start: _at(15)),
  _card('d', section: TimelineSection.amanha, start: _at(9, addDays: 1)),
];

/// The list with [id] lifted out and put back at [index].
///
/// The real server also rewrites every hour the move disturbed. The order is
/// the part the bloc is responsible for drawing, so that is the part the
/// double bothers to get right.
List<TimelineEvent> _moved(String id, int index) {
  final cards = [..._cards];
  final card = cards.removeAt(cards.indexWhere((c) => c.id == id));

  return cards..insert(index.clamp(0, cards.length), card);
}

void main() {
  late TimelineRepository repository;

  setUp(() {
    repository = _MockTimelineRepository();
    when(repository.fetchEvents).thenAnswer((_) async => _cards);
    when(() => repository.moveEvent(any(), any())).thenAnswer(
      (invocation) async => TimelineOutcome(
        cards: _moved(
          invocation.positionalArguments[0] as String,
          invocation.positionalArguments[1] as int,
        ),
      ),
    );
    when(() => repository.finishEvent(any())).thenAnswer((_) async => []);
  });

  TimelineBloc build() => TimelineBloc(repository: repository);

  List<String> order(TimelineState state) =>
      state.cards.map((card) => card.id).toList();

  group('TimelineBloc', () {
    blocTest<TimelineBloc, TimelineState>(
      'loads the day',
      build: build,
      act: (bloc) => bloc.add(const TimelineRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.inSection(TimelineSection.hoje), hasLength(2));
        expect(bloc.state.status, TimelineStatus.success);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'draws the order the server sends back after a drop',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['c', 'a', 'b', 'd']);
        verify(() => repository.moveEvent('c', 0)).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'leaves the timeline alone and raises the guard the move came back with',
      build: () {
        when(() => repository.moveEvent(any(), any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _cards, guard: _guard),
        );
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.guard, _guard);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'refuses to move a meeting Lunna did not book',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: [
          ..._cards,
          _card(
            'daily',
            section: TimelineSection.hoje,
            start: _at(11),
            managed: false,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'daily', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => repository.moveEvent(any(), any()));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'answers a guard and draws what came back',
      build: () {
        when(() => repository.applyTiming(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _moved('c', 0)),
        );
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
        guard: _guard,
      ),
      act: (bloc) => bloc.add(const GuardAnswered(TimingDecision.solveCurrent)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['c', 'a', 'b', 'd']);
        verify(
          () => repository.applyTiming({
            'eventId': 'c',
            'index': 0,
            'decision': 'solve_current',
          }),
        ).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'dropping a guard changes nothing',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
        guard: _guard,
      ),
      act: (bloc) => bloc.add(const GuardDismissed()),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        verifyNever(() => repository.applyTiming(any()));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'takes a finished card off the day before the write lands',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventFinished('b')),
      verify: (bloc) {
        expect(order(bloc.state), isNot(contains('b')));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'keeps the sentence the server refused in',
      build: () {
        when(
          () => repository.createEvent(
            title: any(named: 'title'),
            durationMinutes: any(named: 'durationMinutes'),
            fixed: any(named: 'fixed'),
            startTime: any(named: 'startTime'),
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
        expect(bloc.state.cards, isEmpty);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'puts a finished card back when the write fails',
      build: () {
        when(() => repository.finishEvent(any())).thenThrow(Exception('nope'));
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
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
        when(() => repository.deleteEvent(any())).thenThrow(Exception('nope'));
        return build();
      },
      seed: () => TimelineState(status: TimelineStatus.success, cards: _cards),
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
      'pauses a running card and draws it paused before the server answers',
      build: () {
        when(() => repository.pauseEvent(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _cards;
        });
        return build();
      },
      seed: () => TimelineState(status: TimelineStatus.success, cards: _cards),
      act: (bloc) => bloc.add(const EventPauseToggled('a')),
      wait: const Duration(milliseconds: 5),
      verify: (bloc) {
        expect(bloc.state.byId('a')!.isPaused, isTrue);
        verify(() => repository.pauseEvent('a')).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'resumes a paused card with the same button',
      build: () {
        when(
          () => repository.resumeEvent(any()),
        ).thenAnswer((_) async => _cards);
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: [
          _cards.first.copyWith(pausedAt: _at(9, minute: 10)),
          ..._cards.skip(1),
        ],
      ),
      act: (bloc) => bloc.add(const EventPauseToggled('a')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(() => repository.resumeEvent('a')).called(1);
        expect(bloc.state.byId('a')!.isPaused, isFalse);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'gives fifteen more minutes and draws the day that comes back',
      build: () {
        when(
          () => repository.extendEvent(any(), any()),
        ).thenAnswer((_) async => _cards.reversed.toList());
        return build();
      },
      seed: () => TimelineState(status: TimelineStatus.success, cards: _cards),
      act: (bloc) => bloc.add(const EventExtended('a')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(() => repository.extendEvent('a', 15)).called(1);
        expect(order(bloc.state), ['d', 'c', 'b', 'a']);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'writes something down and draws the day it came back in',
      build: () {
        when(
          () => repository.createEvent(
            title: any(named: 'title'),
            durationMinutes: any(named: 'durationMinutes'),
            fixed: any(named: 'fixed'),
            startTime: any(named: 'startTime'),
          ),
        ).thenAnswer((_) async => _cards);
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
      },
    );
  });

  blocTest<TimelineBloc, TimelineState>(
    'saves notes and draws the day that comes back',
    setUp: () {
      when(
        () => repository.editEvent(any(), notes: any(named: 'notes')),
      ).thenAnswer((_) async => _cards);
    },
    build: () => TimelineBloc(repository: repository),
    seed: () => TimelineState(status: TimelineStatus.success, cards: _cards),
    act: (bloc) => bloc.add(const EventEdited('a', notes: 'Seção 3.')),
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(() => repository.editEvent('a', notes: 'Seção 3.')).called(1);
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
          _card('b', section: TimelineSection.hoje, start: _at(14)),
        ],
        const Duration(minutes: 30),
        now: _at(9),
      );

      expect(start, _at(9, minute: 35));
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

  group('TimelineEvent progress', () {
    final card = _card('a', section: TimelineSection.agora, start: _at(9));

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

  group('a block waiting to be begun', () {
    blocTest<TimelineBloc, TimelineState>(
      'is drawn as begun before the server answers',
      setUp: () {
        when(() => repository.startEvent(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _cards),
        );
      },
      build: () => TimelineBloc(repository: repository),
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: [
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
        verify(() => repository.startEvent('a')).called(1);
        expect(bloc.state.cards, _cards);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'is asked about even before the day has loaded',
      setUp: () {
        when(
          () => repository.snoozeEvent(any(), minutes: any(named: 'minutes')),
        ).thenAnswer((_) async => _cards);
      },
      build: () => TimelineBloc(repository: repository),
      act: (bloc) => bloc.add(const EventSnoozed('a')),
      verify: (_) {
        verify(() => repository.snoozeEvent('a')).called(1);
      },
    );
  });

  blocTest<TimelineBloc, TimelineState>(
    'a drop into a gap sends where the gap starts and the cut length',
    setUp: () {
      when(
        () => repository.moveEvent(
          any(),
          any(),
          after: any(named: 'after'),
          minutes: any(named: 'minutes'),
        ),
      ).thenAnswer((_) async => TimelineOutcome(cards: _cards));
    },
    build: () => TimelineBloc(repository: repository),
    seed: () => TimelineState(status: TimelineStatus.success, cards: _cards),
    act: (bloc) => bloc.add(
      EventMoved(id: 'c', index: 1, after: _at(11), minutes: 20),
    ),
    verify: (_) {
      verify(
        () => repository.moveEvent('c', 1, after: _at(11), minutes: 20),
      ).called(1);
    },
  );
}
