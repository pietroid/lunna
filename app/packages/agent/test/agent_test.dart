import 'package:agent/agent.dart';
import 'package:api_client/api_client.dart';
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
      expect(changes.first.end!.difference(changes.first.at!).inMinutes, 120);
      expect(changes.last.kind, PlanChangeKind.moveEvent);
      expect(changes.last.kind.fixed, isTrue);
      expect(changes.last.before, isNotNull);
      expect(changes.last.routine, isTrue);
    });

    test('reads a doubt: one question, an answer to tap for each reading', () {
      final reply = AgentReply.fromJson(const {
        'reply': 'Você já tem Dentista hoje às 16:00. É esse, ou é outro?',
        'steps': ['Já existe Dentista · bloco fixo · hoje 16:00'],
        'options': [
          {
            'label': 'Mover o de hoje',
            'plan': {
              'id': 'p1',
              'changes': [
                {
                  'kind': 'move_event',
                  'id': 'e1',
                  'title': 'Dentista',
                  'minutes': 60,
                  'at': '2026-10-17T12:00:00.000Z',
                  'before': '2026-10-16T19:00:00.000Z',
                  'routine': false,
                },
              ],
            },
          },
          {
            'label': 'Deixar para depois',
            'plan': {
              'id': 'p2',
              'changes': [
                {
                  'kind': 'to_backlog',
                  'title': 'Treinar',
                  'minutes': 30,
                  'routine': false,
                },
              ],
              'assumed': [
                {'kind': 'minutes', 'minutes': 30},
                {'kind': 'today'},
                {'kind': 'something_new'},
              ],
            },
          },
        ],
      });

      expect(reply.plan, isNull);
      expect(reply.options.map((it) => it.label), [
        'Mover o de hoje',
        'Deixar para depois',
      ]);
      expect(reply.plans.map((it) => it.id), ['p1', 'p2']);
      final backlog = reply.options.last.plan;
      expect(backlog.changes.single.kind, PlanChangeKind.toBacklog);
      expect(backlog.changes.single.at, isNull);
      expect(backlog.assumed, const [
        PlanAssumption(PlanAssumptionKind.minutes, minutes: 30),
        PlanAssumption(PlanAssumptionKind.today),
      ]);
    });

    test('reads a place in the queue, by the cards around it', () {
      final change = PlanChange.fromJson(const {
        'kind': 'add_task',
        'title': 'Revisar proposta',
        'minutes': 45,
        'at': '2026-10-16T20:05:00.000Z',
        'routine': false,
        'place': {'after': 'Academia', 'before': 'Jantar'},
      });

      expect(
        change.place,
        const PlanPlace(after: 'Academia', before: 'Jantar'),
      );
    });

    test('reads what a plan pushes later', () {
      final plan = AgentPlan.fromJson(const {
        'id': 'p1',
        'changes': <Object>[],
        'pushed': [
          {
            'id': 't1',
            'title': 'Responder e-mails',
            'before': '2026-10-15T18:00:00.000Z',
            'at': '2026-10-15T19:05:00.000Z',
          },
        ],
      });

      expect(plan.pushed.single.title, 'Responder e-mails');
      expect(
        plan.pushed.single.at.difference(plan.pushed.single.before),
        const Duration(minutes: 65),
      );
    });

    test('a reply with no plan has none', () {
      expect(AgentReply.fromJson(const {'reply': 'Oi'}).plan, isNull);
    });
  });

  group('PastConversation.fromJson', () {
    test('reads the messages back as the conversation drew them', () {
      final past = PastConversation.fromJson(const {
        'id': 'c1',
        'startedAt': '2026-10-14T21:40:00.000Z',
        'messages': [
          {
            'role': 'user',
            'text': 'Passa a academia',
            'steps': <String>[],
            'voiceSeconds': 4,
            'at': '2026-10-14T21:40:00.000Z',
          },
          {
            'role': 'assistant',
            'text': 'Fica assim:',
            'steps': ['Olhei amanhã'],
            'plan': {'id': 'p1', 'changes': <Object>[], 'pushed': <Object>[]},
            'planStatus': 'undone',
            'at': '2026-10-14T21:40:00.001Z',
          },
        ],
      });

      expect(past.entries, [
        const UserEntry('Passa a academia', voice: Duration(seconds: 4)),
        const ReplyEntry(_reply, status: PlanStatus.undone),
      ]);
    });
  });

  group('AgentFailure.from', () {
    DioException refused(Map<String, dynamic> body) => DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 409,
        data: body,
      ),
    );

    test('reads the kind and the trace the server sends', () {
      final failure = AgentFailure.from(
        refused({'message': 'O dia mudou', 'kind': 'drift', 'traceId': 't1'}),
      );

      expect(failure.kind, AgentFailureKind.drift);
      expect(failure.traceId, 't1');
      expect(failure.message, 'O dia mudou');
    });

    test('is offline when the server never answered', () {
      final failure = AgentFailure.from(
        DioException(requestOptions: RequestOptions()),
      );

      expect(failure.kind, AgentFailureKind.offline);
    });

    test('is ours to fix when the kind is unknown', () {
      expect(
        AgentFailure.from(refused({'message': 'x'})).kind,
        AgentFailureKind.bug,
      );
    });
  });

  group('AgentCubit', () {
    late AgentRepository repository;
    final start = DateTime(2026, 10, 15, 14, 12);

    void answers(AgentReply reply) => when(
      () => repository.turn(
        any(),
        conversationId: any(named: 'conversationId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async => (conversationId: 'c2', reply: reply));

    setUp(() => repository = _MockRepository());

    blocTest<AgentCubit, AgentState>(
      'says what the user said, then what the agent answered',
      setUp: () => answers(_reply),
      build: () => AgentCubit(repository: repository, now: () => start),
      act: (cubit) => cubit.send('  Encaixa estudo  '),
      expect: () => [
        AgentState(
          entries: const [UserEntry('Encaixa estudo')],
          startedAt: start,
          busy: true,
        ),
        AgentState(
          conversationId: 'c2',
          startedAt: start,
          entries: const [UserEntry('Encaixa estudo'), ReplyEntry(_reply)],
        ),
      ],
    );

    blocTest<AgentCubit, AgentState>(
      'carries the conversation on, and sends only it',
      setUp: () => answers(_reply),
      build: () => AgentCubit(repository: repository, now: () => start),
      seed: () => AgentState(
        conversationId: 'c2',
        startedAt: start,
        entries: const [UserEntry('Oi'), ReplyEntry(_reply)],
        past: [
          PastConversation(
            id: 'c1',
            startedAt: start.subtract(const Duration(days: 1)),
            entries: const [UserEntry('Ontem')],
          ),
        ],
      ),
      act: (cubit) => cubit.send('E amanhã?'),
      verify: (_) {
        final sent =
            verify(
                  () => repository.turn(
                    captureAny(),
                    conversationId: 'c2',
                    day: any(named: 'day'),
                  ),
                ).captured.single
                as List<AgentEntry>;
        expect(sent, const [
          UserEntry('Oi'),
          ReplyEntry(_reply),
          UserEntry('E amanhã?'),
        ]);
      },
    );

    blocTest<AgentCubit, AgentState>(
      'keeps what the user said when the agent fails',
      setUp: () => when(
        () => repository.turn(
          any(),
          conversationId: any(named: 'conversationId'),
          day: any(named: 'day'),
        ),
      ).thenThrow(const AgentFailure('Não consegui')),
      build: () => AgentCubit(repository: repository, now: () => start),
      act: (cubit) => cubit.send('Oi'),
      expect: () => [
        AgentState(
          entries: const [UserEntry('Oi')],
          startedAt: start,
          busy: true,
        ),
        AgentState(
          entries: const [UserEntry('Oi')],
          startedAt: start,
          failure: const AgentFailure('Não consegui'),
        ),
      ],
    );

    blocTest<AgentCubit, AgentState>(
      'asks again for the turn that failed, once',
      setUp: () => answers(_reply),
      build: () => AgentCubit(repository: repository, now: () => start),
      seed: () => AgentState(
        entries: const [UserEntry('Oi')],
        startedAt: start,
        failure: const AgentFailure(null, AgentFailureKind.modelDown),
      ),
      act: (cubit) => cubit.retry(),
      verify: (cubit) {
        expect(cubit.state.entries, const [
          UserEntry('Oi'),
          ReplyEntry(_reply),
        ]);
        expect(cubit.state.failure, isNull);
      },
    );

    test(
      'opening starts a new conversation and puts the last one above',
      () async {
        final yesterday = PastConversation(
          id: 'c0',
          startedAt: start.subtract(const Duration(days: 1)),
          entries: const [UserEntry('Ontem')],
        );
        when(
          () => repository.conversations(before: any(named: 'before')),
        ).thenAnswer((_) async => [yesterday]);
        answers(_reply);
        final cubit = AgentCubit(repository: repository, now: () => start)
          ..open();
        await pumpEventQueue();
        expect(cubit.state.past, [yesterday]);
        expect(cubit.state.pastStatus, PastStatus.done);

        await cubit.send('Oi');
        cubit.open();

        expect(cubit.state.entries, isEmpty);
        expect(cubit.state.conversationId, isNull);
        expect(cubit.state.past.map((it) => it.id), ['c2', 'c0']);
        expect(cubit.state.past.first.startedAt, start);
        // The past is read once, not on every opening.
        verify(
          () => repository.conversations(before: any(named: 'before')),
        ).called(1);
        await cubit.close();
      },
    );

    test('pages back from the oldest conversation held', () async {
      final page = List.generate(
        AgentCubit.pageSize,
        (i) => PastConversation(
          id: 'c$i',
          startedAt: start.subtract(Duration(hours: i + 1)),
          entries: const [UserEntry('Oi')],
        ),
      );
      when(
        () => repository.conversations(before: any(named: 'before')),
      ).thenAnswer((_) async => page);
      final cubit = AgentCubit(repository: repository, now: () => start);

      await cubit.loadPast();
      expect(cubit.state.pastStatus, PastStatus.idle);

      when(
        () => repository.conversations(before: any(named: 'before')),
      ).thenAnswer((_) async => []);
      await cubit.loadPast();

      verify(
        () => repository.conversations(before: page.last.startedAt),
      ).called(1);
      expect(cubit.state.pastStatus, PastStatus.done);
      expect(cubit.state.past, page);
      await cubit.close();
    });

    blocTest<AgentCubit, AgentState>(
      'says nothing for an empty message',
      build: () => AgentCubit(repository: repository),
      act: (cubit) => cubit.send('   '),
      expect: () => <AgentState>[],
    );

    blocTest<AgentCubit, AgentState>(
      'marks where a plan stands, wherever it was proposed',
      build: () => AgentCubit(repository: repository),
      seed: () => AgentState(
        entries: const [ReplyEntry(_reply)],
        past: [
          PastConversation(
            id: 'c1',
            startedAt: start,
            entries: const [ReplyEntry(_reply)],
          ),
        ],
      ),
      act: (cubit) => cubit.markPlan('p1', PlanStatus.undone),
      expect: () => [
        AgentState(
          entries: const [
            ReplyEntry(_reply, status: PlanStatus.undone, chosen: 'p1'),
          ],
          past: [
            PastConversation(
              id: 'c1',
              startedAt: start,
              entries: const [
                ReplyEntry(_reply, status: PlanStatus.undone, chosen: 'p1'),
              ],
            ),
          ],
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
