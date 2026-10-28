import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ArtifactsRepository {}

void main() {
  late _MockRepository repository;
  Artifact artifact(String id, {DateTime? doneAt}) => Artifact(
    id: id,
    title: 'Entrega $id',
    minutes: 60,
    createdAt: DateTime(2026, 6),
    deadline: DateTime(2026, 6, 10),
    doneAt: doneAt,
  );
  final schedule = Schedule(
    needMinutes: 60,
    freeMinutes: 600,
    until: DateTime(2026, 6, 30),
  );
  final data = ArtifactsData(
    artifacts: [artifact('a'), artifact('b'), artifact('c')],
    schedule: schedule,
  );
  final ready = ArtifactsState(status: ArtifactsStatus.ready, data: data);

  setUp(() => repository = _MockRepository());

  blocTest<ArtifactsCubit, ArtifactsState>(
    'reads everything',
    setUp: () => when(() => repository.load()).thenAnswer((_) async => data),
    build: () => ArtifactsCubit(repository: repository),
    act: (cubit) => cubit.load(),
    expect: () => [ready],
  );

  test(
    'draws a dragged delivery in its new place before the server answers',
    () async {
      when(() => repository.move('c', 0)).thenAnswer((_) async => data);
      final cubit = ArtifactsCubit(repository: repository, initial: ready);
      final states = <ArtifactsState>[];
      final listening = cubit.stream.listen(states.add);

      await cubit.move('c', 0);
      await listening.cancel();

      expect(states.first.queue.map((a) => a.id), ['c', 'a', 'b']);
      verify(() => repository.move('c', 0)).called(1);
    },
  );

  test(
    'tells the day when a delivery is removed, since its backlog goes',
    () async {
      var told = 0;
      when(() => repository.delete(any())).thenAnswer((_) async => data);
      final cubit = ArtifactsCubit(
        repository: repository,
        onDayChanged: () => told++,
      );

      await cubit.delete('a');
      expect(told, 1);
    },
  );

  test('moves the deadline a day at a time', () async {
    DateTime? sent;
    when(
      () => repository.update(any(), deadline: any(named: 'deadline')),
    ).thenAnswer((invocation) async {
      final deadline =
          invocation.namedArguments[#deadline] as DateTime? Function();
      sent = deadline();
      return data;
    });
    final cubit = ArtifactsCubit(repository: repository, initial: ready);

    await cubit.shiftDeadline('a', 1);
    expect(sent, DateTime(2026, 6, 11));
    await cubit.shiftDeadline('a', -1);
    expect(sent, DateTime(2026, 6, 9));
  });

  test(
    'hands a kind and a goal to the server, and says it took them',
    () async {
      const mapa = CatalogType(id: 'mapa', name: 'Mapa astral', minutes: 90);
      when(
        () => repository.create(
          title: any(named: 'title'),
          typeId: any(named: 'typeId'),
          minutes: any(named: 'minutes'),
          value: any(named: 'value'),
          blockMinutes: any(named: 'blockMinutes'),
          deadline: any(named: 'deadline'),
          top: any(named: 'top'),
        ),
      ).thenAnswer((_) async => data);
      when(
        () => repository.addGoal(
          target: 10000,
          deadline: DateTime(2026, 11, 30),
        ),
      ).thenAnswer((_) async => data);
      when(
        () => repository.updateGoal('g', target: 12000),
      ).thenAnswer((_) async => data);
      final cubit = ArtifactsCubit(repository: repository, initial: ready);

      expect(
        await cubit.create(title: 'Mapa · Ana', type: mapa, top: true),
        isTrue,
      );
      verify(
        () => repository.create(title: 'Mapa · Ana', typeId: 'mapa', top: true),
      ).called(1);
      expect(
        await cubit.addGoal(target: 10000, deadline: DateTime(2026, 11, 30)),
        isTrue,
      );
      expect(await cubit.editGoal('g', target: 12000), isTrue);
    },
  );

  blocTest<ArtifactsCubit, ArtifactsState>(
    'keeps what it had and says why when a write is refused',
    setUp: () => when(
      () => repository.update(any(), done: any(named: 'done')),
    ).thenThrow(const ArtifactsFailure('Essa entrega não existe mais.')),
    build: () => ArtifactsCubit(repository: repository, initial: ready),
    act: (cubit) => cubit.setDone('a', done: true),
    expect: () => [
      ArtifactsState(
        status: ArtifactsStatus.ready,
        data: data,
        failure: const ArtifactsFailure('Essa entrega não existe mais.'),
      ),
    ],
  );

  test('draws a delivery begun at once, with the day it was given', () async {
    final day = DateTime(2026, 6, 20);
    when(
      () => repository.update(
        'b',
        started: true,
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async => data);
    final cubit = ArtifactsCubit(repository: repository, initial: ready);
    final states = <ArtifactsState>[];
    final listening = cubit.stream.listen(states.add);

    await withClock(
      Clock.fixed(DateTime(2026, 6, 5, 9)),
      () => cubit.start('b', deadline: day),
    );
    await listening.cancel();

    final begun = states.first.byId('b')!;
    expect(begun.startedAt, DateTime(2026, 6, 5, 9));
    expect(begun.deadline, day);
  });

  test('puts a refused start back as it was', () async {
    when(
      () => repository.update('b', started: true),
    ).thenThrow(const ArtifactsFailure('Dê um prazo para começar a entrega.'));
    final cubit = ArtifactsCubit(repository: repository, initial: ready);

    await cubit.start('b');

    expect(cubit.state.byId('b')!.startedAt, isNull);
    expect(cubit.state.failure?.message, 'Dê um prazo para começar a entrega.');
  });

  test('draws a stopped delivery in its place among those not begun', () async {
    final begun = ArtifactsState(
      status: ArtifactsStatus.ready,
      data: ArtifactsData(
        artifacts: [
          artifact('a'),
          artifact('b').copyWith(startedAt: () => DateTime(2026, 6, 2)),
          artifact('c'),
        ],
        schedule: schedule,
      ),
    );
    when(
      () => repository.move('b', 2, stop: true),
    ).thenAnswer((_) async => data);
    final cubit = ArtifactsCubit(repository: repository, initial: begun);
    final states = <ArtifactsState>[];
    final listening = cubit.stream.listen(states.add);

    await cubit.stop('b', 2);
    await listening.cancel();

    expect(states.first.queue.map((a) => a.id), ['a', 'c', 'b']);
    expect(states.first.byId('b')!.startedAt, isNull);
    verify(() => repository.move('b', 2, stop: true)).called(1);
  });
}
