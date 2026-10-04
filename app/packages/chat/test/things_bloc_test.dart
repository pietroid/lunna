import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockThingsRepository extends Mock implements ThingsRepository {}

const _a = Thing(id: 'a', title: 'Um', durationMinutes: 30);
const _b = Thing(id: 'b', title: 'Dois', durationMinutes: 15);
const _c = Thing(id: 'c', title: 'Três', durationMinutes: 45);

void main() {
  late ThingsRepository repository;

  setUp(() => repository = _MockThingsRepository());

  const seeded = ThingsState(
    status: ThingsStatus.success,
    things: [_a, _b, _c],
  );

  blocTest<ThingsBloc, ThingsState>(
    'draws a move before the server answers',
    setUp: () => when(
      () => repository.moveThing(any(), any()),
    ).thenAnswer((_) async => const [_c, _a, _b]),
    build: () => ThingsBloc(repository: repository),
    seed: () => seeded,
    act: (bloc) => bloc.add(const ThingMoved(id: 'c', index: 0)),
    expect: () => [
      seeded.copyWith(things: const [_c, _a, _b]),
    ],
  );

  blocTest<ThingsBloc, ThingsState>(
    'puts a finished thing back when the server refuses',
    setUp: () => when(
      () => repository.finishThing(any()),
    ).thenThrow(const ChatFailure('Não consegui.')),
    build: () => ThingsBloc(repository: repository),
    seed: () => seeded,
    act: (bloc) => bloc.add(const ThingFinished('a')),
    verify: (bloc) => expect(bloc.state.things, const [_a, _b, _c]),
  );

  blocTest<ThingsBloc, ThingsState>(
    'says which thing went onto the timeline',
    setUp: () =>
        when(
          () => repository.scheduleThing(any()),
        ).thenAnswer(
          (_) async => (things: const [_a, _c], cards: <TimelineEvent>[]),
        ),
    build: () => ThingsBloc(repository: repository),
    seed: () => seeded,
    act: (bloc) => bloc.add(const ThingScheduled('b')),
    verify: (bloc) {
      expect(bloc.state.things, const [_a, _c]);
      expect(bloc.state.scheduled, _b);
      expect(bloc.state.scheduledCount, 1);
    },
  );
}
