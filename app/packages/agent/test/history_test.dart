import 'package:agent/agent.dart';
import 'package:agent/src/view/plan_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockRepository extends Mock implements AgentRepository {}

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

class _FakeRecognizer extends Fake implements VoiceRecognizer {}

final _now = DateTime.now();

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

      expect(find.text('Como posso arrumar seu dia?'), findsOneWidget);
      expect(find.text('Conversas anteriores'), findsOneWidget);
      expect(find.text('Coloca dentista às 15h').hitTestable(), findsNothing);
    });

    testWidgets('pulled down, shows the past under its hour, read only', (
      tester,
    ) async {
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

  group('PlanCard', () {
    testWidgets('a plan that pushes asks: Outro horário or Empurrar', (
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
      expect(find.text('Empurrar'), findsOneWidget);
      await tester.tap(find.text('Outro horário'));
      expect(adjusted, isTrue);
    });
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
