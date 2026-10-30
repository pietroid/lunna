import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/feed/feed.dart';
import 'package:lunna/plan/plan.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

class _MockAgentRepository extends Mock implements AgentRepository {}

class _MockArtifactsRepository extends Mock implements ArtifactsRepository {}

void main() {
  /// Wednesday 28 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 28, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  TimelineEvent card(
    String id,
    String title,
    TimelineSection section, {
    required int at,
    CardKind kind = CardKind.task,
  }) {
    final start = now.add(Duration(minutes: at));
    return TimelineEvent(
      id: id,
      title: title,
      section: section,
      kind: kind,
      startTime: start,
      endTime: start.add(const Duration(minutes: 45)),
      durationMinutes: 45,
    );
  }

  Artifact delivery(String id, String title, {DateTime? startedAt}) => Artifact(
    id: id,
    title: title,
    minutes: 180,
    createdAt: DateTime(2026, 10),
    deadline: DateTime(2026, 11, 5),
    startedAt: startedAt,
  );

  Goal goal({required DateTime start, required DateTime end}) => Goal(
    id: 'g',
    kind: GoalKind.money,
    target: 10000,
    done: 2850,
    start: start,
    end: end,
  );

  ArtifactsData artifacts({
    List<Artifact> queue = const [],
    List<Goal> goals = const [],
  }) => ArtifactsData(
    artifacts: queue,
    goals: goals,
    schedule: Schedule(
      needMinutes: 0,
      freeMinutes: 0,
      until: DateTime(2026, 10, 31),
    ),
  );

  late _MockTimelineBloc timeline;
  late _MockAgentRepository agent;
  late List<PlanTab> opened;

  setUp(() {
    // The offer asks whether it was put away.
    SharedPreferences.setMockInitialValues({});
    timeline = _MockTimelineBloc();
    agent = _MockAgentRepository();
    opened = [];
    when(() => agent.suggestion()).thenAnswer((_) async => null);
  });

  Future<void> pump(
    WidgetTester tester, {
    List<TimelineEvent> cards = const [],
    ArtifactsData? data,
    bool shown = true,
    List<DayMark> marks = const [],
  }) async {
    // Wide: the test font draws every letter as a square, and the offer's
    // two buttons would not fit side by side on a phone in it.
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => timeline.state,
    ).thenReturn(TimelineState(cards: cards, marks: marks));

    await tester.pumpWidget(
      RepositoryProvider<AgentRepository>.value(
        value: agent,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<TimelineBloc>.value(value: timeline),
            BlocProvider(
              create: (_) => ArtifactsCubit(
                repository: _MockArtifactsRepository(),
                initial: ArtifactsState(
                  status: ArtifactsStatus.ready,
                  data: data ?? artifacts(),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.current,
            locale: const Locale('pt', 'BR'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FeedPage(shown: shown, onOpen: opened.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testAt('says each section is empty when there is nothing in it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(l10n.feedBreak), findsOneWidget);
    expect(find.text(l10n.feedNoDelivery), findsOneWidget);
    expect(find.text(l10n.feedNoGoal), findsOneWidget);
    expect(find.text(l10n.feedNext), findsNothing);
  });

  testAt('draws Agora and the one card after it, a fixed block too', (
    tester,
  ) async {
    await pump(
      tester,
      cards: [
        card('a', 'Revisar o contrato', TimelineSection.agora, at: -10),
        card(
          'b',
          'Standup',
          TimelineSection.dia,
          at: 40,
          kind: CardKind.event,
        ),
        card('c', 'Responder e-mails', TimelineSection.dia, at: 90),
      ],
    );

    expect(find.text('Revisar o contrato'), findsOneWidget);
    expect(find.text(l10n.feedNext), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    // The home is not a list: one card after Agora.
    expect(find.text('Responder e-mails'), findsNothing);
    expect(find.text(l10n.feedBreak), findsNothing);
  });

  testAt('puts the delivery Entregas puts first: begun before waiting', (
    tester,
  ) async {
    await pump(
      tester,
      data: artifacts(
        queue: [
          delivery('w', 'Post de novembro'),
          delivery('s', 'Mapa · Renata', startedAt: DateTime(2026, 10, 20)),
        ],
      ),
    );

    expect(find.byType(ArtifactRow), findsOneWidget);
    expect(find.text('Mapa · Renata'), findsOneWidget);
    expect(find.text('Post de novembro'), findsNothing);
  });

  testAt('falls back on the first not begun', (tester) async {
    await pump(
      tester,
      data: artifacts(
        queue: [
          delivery('w', 'Post de novembro'),
          delivery('x', 'Mapa · Carla'),
        ],
      ),
    );

    expect(find.text('Post de novembro'), findsOneWidget);
    expect(find.text('Mapa · Carla'), findsNothing);
  });

  testAt('does not draw a goal that has not begun', (
    tester,
  ) async {
    await pump(
      tester,
      data: artifacts(
        goals: [goal(start: DateTime(2026, 12), end: DateTime(2027))],
      ),
    );
    expect(find.byType(GoalCard), findsNothing);
    expect(find.text(l10n.feedNoGoal), findsOneWidget);
  });

  testAt('draws the goal whose days are running', (tester) async {
    await pump(
      tester,
      data: artifacts(
        goals: [goal(start: DateTime(2026, 10), end: DateTime(2026, 12))],
      ),
    );
    expect(find.byType(GoalCard), findsOneWidget);
  });

  testAt('each heading opens its level of Plano', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.feedSeeDay));
    await tester.tap(
      find.widgetWithText(AppPillButton, l10n.feedSeeDeliveries),
    );
    await tester.tap(find.widgetWithText(AppPillButton, l10n.feedSeeGoals));

    expect(opened, [PlanTab.calendar, PlanTab.deliveries, PlanTab.goals]);
  });

  testAt('asks for the offer when shown, and again when brought back', (
    tester,
  ) async {
    await pump(tester);
    verify(() => agent.suggestion()).called(1);

    await pump(tester, shown: false);
    verifyNever(() => agent.suggestion());

    await pump(tester);
    verify(() => agent.suggestion()).called(1);
  });

  testAt('draws the offer above Agora', (tester) async {
    when(() => agent.suggestion()).thenAnswer(
      (_) async => const AgentSuggestion(
        id: 's',
        text: 'Encaixo 45 min do mapa às 11:10?',
      ),
    );
    await pump(tester);
    await tester.pump();

    expect(find.text('Encaixo 45 min do mapa às 11:10?'), findsOneWidget);
  });

  group('the day’s tag', () {
    final today = DateTime(2026, 10, 28);

    testAt('says the cycle’s day and that the day is light', (tester) async {
      await pump(
        tester,
        marks: [
          DayMark(
            day: today,
            kind: DayKind.light,
            reason: DayReason.period,
            budgetMinutes: 180,
            cycleDay: 2,
            cycleLength: 28,
            phase: CyclePhase.menstrual,
          ),
        ],
      );

      expect(find.text('Dia 2 do ciclo · dia leve'), findsOneWidget);
    });

    testAt('names the phase on a working day', (tester) async {
      await pump(
        tester,
        marks: [
          DayMark(
            day: today,
            cycleDay: 9,
            cycleLength: 28,
            phase: CyclePhase.follicular,
          ),
        ],
      );

      expect(find.text('Dia 9 do ciclo · Folicular'), findsOneWidget);
    });

    testAt('says a day off without a cycle', (tester) async {
      await pump(
        tester,
        marks: [
          DayMark(day: today, kind: DayKind.off, reason: DayReason.dayOff),
        ],
      );

      expect(find.text(l10n.dayOffTag), findsOneWidget);
    });

    testAt('draws nothing on a plain working day', (tester) async {
      await pump(tester);

      expect(find.textContaining('do ciclo'), findsNothing);
      expect(find.text(l10n.dayOffTag), findsNothing);
    });
  });
}
