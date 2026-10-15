import 'package:agent/agent.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRepository extends Mock implements AgentRepository {}

const _plan = AgentPlan(id: 'p1', changes: []);
const _reply = AgentReply(
  text: 'Fica assim:',
  steps: ['Olhei amanhã'],
  plan: _plan,
);

void main() {
  setUpAll(() => registerFallbackValue(<AgentEntry>[]));

  group('AgentReply.fromJson', () {
    test('reads the reply, the steps and the plan', () {
      final reply = AgentReply.fromJson(const {
        'reply': 'Fica assim:',
        'steps': ['Olhei amanhã', 'Achei 08:00–10:00 livre'],
        'plan': {
          'id': 'p1',
          'changes': [
            {
              'kind': 'add_task',
              'title': 'Estudo',
              'minutes': 120,
              'at': '2026-10-16T11:00:00.000Z',
              'routine': false,
            },
            {
              'kind': 'move_event',
              'id': 'e1',
              'title': 'Academia',
              'minutes': 60,
              'at': '2026-10-16T21:30:00.000Z',
              'before': '2026-10-16T11:00:00.000Z',
              'routine': true,
            },
          ],
        },
      });

      expect(reply.steps, hasLength(2));
      final changes = reply.plan!.changes;
      expect(changes.first.kind, PlanChangeKind.addTask);
      expect(changes.first.kind.adds, isTrue);
      expect(changes.first.end.difference(changes.first.at).inMinutes, 120);
      expect(changes.last.kind, PlanChangeKind.moveEvent);
      expect(changes.last.kind.fixed, isTrue);
      expect(changes.last.before, isNotNull);
      expect(changes.last.routine, isTrue);
    });

    test('a reply with no plan has none', () {
      expect(AgentReply.fromJson(const {'reply': 'Oi'}).plan, isNull);
    });
  });

  group('AgentCubit', () {
    late AgentRepository repository;

    setUp(() => repository = _MockRepository());

    blocTest<AgentCubit, AgentState>(
      'says what the user said, then what the agent answered',
      setUp: () => when(
        () => repository.turn(any(), day: any(named: 'day')),
      ).thenAnswer((_) async => _reply),
      build: () => AgentCubit(repository: repository),
      act: (cubit) => cubit.send('  Encaixa estudo  '),
      expect: () => [
        const AgentState(entries: [UserEntry('Encaixa estudo')], busy: true),
        const AgentState(
          entries: [UserEntry('Encaixa estudo'), ReplyEntry(_reply)],
        ),
      ],
    );

    blocTest<AgentCubit, AgentState>(
      'keeps what the user said when the agent fails',
      setUp: () => when(
        () => repository.turn(any(), day: any(named: 'day')),
      ).thenThrow(const AgentFailure('Não consegui')),
      build: () => AgentCubit(repository: repository),
      act: (cubit) => cubit.send('Oi'),
      expect: () => [
        const AgentState(entries: [UserEntry('Oi')], busy: true),
        const AgentState(
          entries: [UserEntry('Oi')],
          failure: AgentFailure('Não consegui'),
        ),
      ],
    );

    blocTest<AgentCubit, AgentState>(
      'says nothing for an empty message',
      build: () => AgentCubit(repository: repository),
      act: (cubit) => cubit.send('   '),
      expect: () => <AgentState>[],
    );

    blocTest<AgentCubit, AgentState>(
      'marks where a plan stands',
      build: () => AgentCubit(repository: repository),
      seed: () => const AgentState(entries: [ReplyEntry(_reply)]),
      act: (cubit) => cubit.markPlan('p1', PlanStatus.applied),
      expect: () => [
        const AgentState(
          entries: [ReplyEntry(_reply, status: PlanStatus.applied)],
        ),
      ],
    );
  });

  group('SuggestionCubit', () {
    late AgentRepository repository;
    const suggestion = AgentSuggestion(text: 'Quer encaixar?', plan: _plan);

    setUp(() {
      repository = _MockRepository();
      SharedPreferences.setMockInitialValues({});
      when(() => repository.suggestion()).thenAnswer((_) async => suggestion);
    });

    test('offers what the server suggests', () async {
      final cubit = SuggestionCubit(repository: repository);
      await cubit.load();

      expect(cubit.state, suggestion);
    });

    test('rests for a day after "Agora não", then offers again', () async {
      final start = DateTime(2026, 10, 15, 9);
      final cubit = SuggestionCubit(repository: repository);

      await withClock(Clock.fixed(start), () async {
        await cubit.load();
        await cubit.dismiss();
        expect(cubit.state, isNull);

        await cubit.load();
        expect(cubit.state, isNull);
      });

      await withClock(
        Clock.fixed(start.add(SuggestionCubit.quiet)),
        cubit.load,
      );
      expect(cubit.state, suggestion);
    });

    test('says nothing when the server fails', () async {
      when(
        () => repository.suggestion(),
      ).thenThrow(const AgentFailure());
      final cubit = SuggestionCubit(repository: repository);
      await cubit.load();

      expect(cubit.state, isNull);
    });
  });
}
