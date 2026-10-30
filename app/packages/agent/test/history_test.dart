import 'package:agent/agent.dart';
import 'package:agent/src/view/plan_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockRepository extends Mock implements AgentRepository {}

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

class _FakeRecognizer extends Fake implements VoiceRecognizer {}

// Midday, so half an hour ago is still today whatever the zone or hour.
final _now = DateTime(2026, 10, 15, 12);

AgentPlan _plan(String id, {List<PushedTask> pushed = const []}) => AgentPlan(
  id: id,
  changes: [
    PlanChange(
      kind: PlanChangeKind.addEvent,
      title: 'Dentista',
      minutes: 60,
      at: DateTime(_now.year, _now.month, _now.day, 15),
    ),
  ],
  pushed: pushed,
);

Widget _app(Widget child, {List<BlocProvider> providers = const []}) =>
    MaterialApp(
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.current,
      home: Scaffold(
        body: providers.isEmpty
            ? child
            : MultiBlocProvider(providers: providers, child: child),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<AgentEntry>[]);
    registerFallbackValue(const TimelineRequested());
  });

  group('AgentSheet history', () {
    late AgentRepository repository;
    late AgentCubit agent;

    setUp(() {
      repository = _MockRepository();
      when(
        () => repository.conversations(before: any(named: 'before')),
      ).thenAnswer((_) async => []);
      agent = AgentCubit(repository: repository)
        ..emit(
          AgentState(
            past: [
              PastConversation(
                id: 'c1',
                startedAt: _now.subtract(const Duration(minutes: 30)),
                entries: [
                  const UserEntry('Coloca dentista às 15h'),
                  ReplyEntry(
                    AgentReply(
                      text: 'Quer que eu empurre o resto?',
                      plan: _plan('p1'),
                    ),
                    status: PlanStatus.applied,
                  ),
                ],
              ),
            ],
            pastStatus: PastStatus.done,
          ),
        );
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          const AgentSheet(),
          providers: [
            BlocProvider<AgentCubit>.value(value: agent),
            BlocProvider<VoiceCubit>(
              create: (_) => VoiceCubit(recognizer: _FakeRecognizer()),
            ),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('opens on the new conversation, the past out of sight', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Pergunte ou peça algo…'), findsOneWidget);
      expect(find.text('Conversas anteriores'), findsOneWidget);
      expect(find.text('Coloca dentista às 15h').hitTestable(), findsNothing);
    });

    testWidgets('pulled down, shows the past under its hour, read only', (
      tester,
    ) async {
      await withClock(Clock.fixed(_now), () async {
        await pump(tester);

        await tester.drag(find.byType(ListView), const Offset(0, 900));
        await tester.pumpAndSettle();

        expect(find.text('Coloca dentista às 15h'), findsOneWidget);
        expect(find.textContaining('Hoje · '), findsOneWidget);
        expect(find.textContaining('Agora · '), findsOneWidget);
        expect(find.text('Dentista 15:00 · aplicado'), findsOneWidget);
        // Read only: the plan is a line, not a card with buttons.
        expect(find.text('Aplicar'), findsNothing);
      });
    });
  });

  group('PlanCard', () {
    testWidgets('a plan that pushes asks: Outro horário or Mover', (
      tester,
    ) async {
      final plan = _plan(
        'p2',
        pushed: [
          PushedTask(
            id: 't1',
            title: 'Responder e-mails',
            before: DateTime(2026, 10, 15, 15),
            at: DateTime(2026, 10, 15, 16, 5),
          ),
        ],
      );
      var adjusted = false;

      await tester.pumpWidget(
        _app(
          PlanCard(
            plan: plan,
            status: PlanStatus.pending,
            onApply: () {},
            onAdjust: () => adjusted = true,
          ),
        ),
      );

      expect(find.text('Responder e-mails'), findsOneWidget);
      expect(
        find.textContaining('16:05 · empurrada', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1 mudança · 1 empurrada'), findsOneWidget);
      expect(find.text('Mover'), findsOneWidget);
      await tester.tap(find.text('Outro horário'));
      expect(adjusted, isTrue);
    });

    testWidgets(
      'draws Entregas’ changes: deliver, move, kind and goals (new, changed, gone)',
      (
        tester,
      ) async {
        final plan = AgentPlan.fromJson(const {
          'id': 'p3',
          'changes': [
            {
              'kind': 'remove_goal',
              'title': 'Meta de posts',
              'minutes': 0,
              'goal': {'kind': 'count', 'period': 'week', 'target': 3},
            },
            {
              'kind': 'deliver',
              'id': 'a1',
              'title': 'Mapa da Ana',
              'minutes': 180,
              'value': 4900,
              'takes': ['Revisar texto'],
            },
            {
              'kind': 'move_artifact',
              'id': 'a2',
              'title': 'Site da Bia',
              'minutes': 0,
              'place': {'before': 'Mapa da Ana'},
            },
            {
              'kind': 'add_kind',
              'title': 'Mapa astral',
              'minutes': 180,
              'shelf': 'Atendimentos',
              'value': 350,
            },
            {
              'kind': 'add_goal',
              'title': 'Faturamento',
              'minutes': 0,
              'goal': {
                'kind': 'money',
                'target': 8000,
                'deadline': '2026-11-30',
              },
            },
            {
              'kind': 'edit_goal',
              'id': 'g2',
              'title': 'Faturamento',
              'minutes': 0,
              'goal': {
                'kind': 'money',
                'target': 9000,
                'deadline': '2026-12-31',
              },
              'wasGoal': {
                'kind': 'money',
                'target': 6000,
                'deadline': '2026-12-31',
              },
            },
          ],
        });

        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: PlanCard(
                plan: plan,
                status: PlanStatus.pending,
                onApply: () {},
                onAdjust: () {},
              ),
            ),
          ),
        );

        for (final detail in [
          r'entregue · R$ 4.900 · 1 tarefa ainda aberta',
          'na fila, antes de Mapa da Ana',
          r'novo tipo · Atendimentos · 3h · R$ 350',
          r'novo objetivo · R$ 8.000 até 30/11',
          r'objetivo · R$ 6.000 até 31/12 → R$ 9.000 até 31/12',
          // A plan kept from before goals had a day.
          'apagar o objetivo · 3 por semana',
        ]) {
          expect(
            find.textContaining(detail, findRichText: true),
            findsOneWidget,
          );
        }
        expect(find.text('Revisar texto'), findsOneWidget);
        // A goal deleted makes the plan a delete.
        expect(find.text('Apagar'), findsOneWidget);
      },
    );

    testWidgets(
      'draws Rotina’s changes and the working day, the old hours struck',
      (tester) async {
        final plan = AgentPlan.fromJson(const {
          'id': 'p4',
          'changes': [
            {
              'kind': 'add_routine',
              'title': 'Manhã de mapas',
              'minutes': 90,
              'routine': true,
              'hours': '08:00–09:30',
              'days': 'weekdays',
              'checklist': ['Café', 'Abrir o mapa', 'Revisar'],
            },
            {
              'kind': 'edit_routine',
              'id': 'r1',
              'title': 'Academia',
              'minutes': 60,
              'routine': true,
              'hours': '07:00–08:00',
              'wasHours': '18:00–19:00',
              'days': 'daily',
              'wasDays': 'weekdays',
            },
            {
              'kind': 'set_work_day',
              'title': 'Dia de trabalho',
              'minutes': 480,
              'hours': '08:00–18:00',
              'wasHours': '07:00–22:00',
            },
            {
              'kind': 'set_rhythm',
              'title': 'Folga em 20/11 · Feriado',
              'minutes': 0,
            },
          ],
        });

        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: PlanCard(
                plan: plan,
                status: PlanStatus.pending,
                onApply: () {},
                onAdjust: () {},
              ),
            ),
          ),
        );

        for (final detail in [
          'nova rotina · 08:00–09:30 · Dias úteis · 3 itens na lista',
          'rotina · 18:00–19:00 → 07:00–08:00 · Dias úteis → Todo dia',
          '07:00–22:00 → 08:00–18:00',
        ]) {
          expect(
            find.textContaining(detail, findRichText: true),
            findsOneWidget,
          );
        }
        expect(find.text('Dia de trabalho'), findsOneWidget);
        expect(find.text('Folga em 20/11 · Feriado'), findsOneWidget);
        expect(
          find.textContaining('Ciclo e folgas', findRichText: true),
          findsOneWidget,
        );
      },
    );
  });

  group('UndoChip', () {
    late AgentRepository repository;
    late TimelineBloc timeline;
    late AgentCubit agent;

    setUp(() {
      repository = _MockRepository();
      timeline = _MockTimelineBloc();
      agent = AgentCubit(repository: repository);
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      RepositoryProvider.value(
        value: repository,
        child: _app(
          const UndoChip(),
          providers: [
            BlocProvider<TimelineBloc>.value(value: timeline),
            BlocProvider<AgentCubit>.value(value: agent),
          ],
        ),
      ),
    );

    testWidgets('is not there with nothing to undo', (tester) async {
      when(() => timeline.state).thenReturn(const TimelineState());
      await pump(tester);

      expect(find.text('Desfazer'), findsNothing);
    });

    testWidgets('takes the plan back and draws the day it answers', (
      tester,
    ) async {
      when(
        () => timeline.state,
      ).thenReturn(const TimelineState(undoable: 'p1'));
      when(
        () => repository.undo('p1', days: any(named: 'days')),
      ).thenAnswer((_) async => const Timeline());
      await pump(tester);

      await tester.tap(find.text('Desfazer'));
      await tester.pump();

      verify(() => repository.undo('p1', days: any(named: 'days'))).called(1);
      verify(() => timeline.add(const TimelineReplaced(Timeline()))).called(1);
    });
  });
}
