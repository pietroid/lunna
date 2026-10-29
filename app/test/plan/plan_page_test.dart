import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/tempo/tempo.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

class _MockAgentCubit extends MockCubit<AgentState> implements AgentCubit {}

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

  group('PlanTab', () {
    test('lights Tarefas for the calendar too', () {
      expect(PlanTab.tasks.level, 0);
      expect(PlanTab.calendar.level, 0);
      expect(PlanTab.deliveries.level, 1);
      expect(PlanTab.goals.level, 2);
      expect([0, 1, 2].map(PlanTab.at), [
        PlanTab.tasks,
        PlanTab.deliveries,
        PlanTab.goals,
      ]);
    });
  });

  late List<PlanTab> selected;

  Future<void> pump(WidgetTester tester, PlanTab tab) async {
    tester.view
      ..physicalSize = const Size(600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timeline = _MockTimelineBloc();
    when(() => timeline.state).thenReturn(
      const TimelineState(status: TimelineStatus.success),
    );
    final agent = _MockAgentCubit();
    when(() => agent.state).thenReturn(const AgentState());

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider(create: (_) => TimelineAim()),
          RepositoryProvider(create: (_) => OpenDayHours(() {})),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<TimelineBloc>.value(value: timeline),
            BlocProvider<AgentCubit>.value(value: agent),
            BlocProvider(create: (_) => TimelineModeCubit()),
            BlocProvider(
              create: (_) => ArtifactsCubit(
                repository: _MockArtifactsRepository(),
                initial: ArtifactsState(
                  status: ArtifactsStatus.ready,
                  data: ArtifactsData(
                    schedule: Schedule(
                      needMinutes: 0,
                      freeMinutes: 0,
                      until: DateTime(2026, 10, 31),
                    ),
                  ),
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
              body: PlanPage(tab: tab, onSelected: selected.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => selected = []);

  testAt('heads the three levels with their names, and picks one', (
    tester,
  ) async {
    await pump(tester, PlanTab.tasks);

    final heading = find.byType(AppTitleTabs);
    expect(heading, findsOneWidget);
    expect(tester.widget<AppTitleTabs>(heading).selected, 0);

    await tester.tap(
      find.descendant(of: heading, matching: find.text(l10n.shellGoalsTab)),
    );
    await tester.tap(
      find.descendant(
        of: heading,
        matching: find.text(l10n.shellArtifactsTab),
      ),
    );
    expect(selected, [PlanTab.goals, PlanTab.deliveries]);
  });

  testAt('draws the level in front and keeps the others alive', (
    tester,
  ) async {
    await pump(tester, PlanTab.goals);

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 2);
    expect(find.byType(TempoPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(ArtifactsPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(GoalsPage), findsOneWidget);
  });

  testAt('carries the search on Entregas only', (tester) async {
    await pump(tester, PlanTab.tasks);
    expect(find.byTooltip(l10n.artifactsSearch), findsNothing);

    await pump(tester, PlanTab.deliveries);
    expect(find.byTooltip(l10n.artifactsSearch), findsOneWidget);

    await pump(tester, PlanTab.goals);
    expect(find.byTooltip(l10n.artifactsSearch), findsNothing);
  });
}
