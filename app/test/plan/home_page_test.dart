import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
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

  setUpAll(() => registerFallbackValue(const TimelineRequested()));

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
    int at = 0,
    CardKind kind = CardKind.task,
    bool started = false,
    String? artifactId,
    String? artifactTitle,
  }) {
    final start = now.add(Duration(minutes: at));
    return TimelineEvent(
      id: id,
      title: title,
      section: section,
      kind: kind,
      started: started,
      startTime: start,
      endTime: start.add(const Duration(minutes: 45)),
      durationMinutes: 45,
      workMinutes: 45,
      artifactId: artifactId,
      artifactTitle: artifactTitle,
    );
  }

  TimelineEvent loose(String id, String title) =>
      card(id, title, TimelineSection.backlog);

  Artifact delivery(String id, String title, {DateTime? startedAt}) => Artifact(
    id: id,
    title: title,
    minutes: 180,
    doneMinutes: 90,
    createdAt: DateTime(2026, 10),
    deadline: DateTime(2026, 11, 3),
    startedAt: startedAt,
    tasks: const [
      ArtifactTask(
        id: 't',
        title: 'Roteiro',
        minutes: 30,
        place: TaskPlace.backlog,
      ),
    ],
  );

  ArtifactsData artifacts(List<Artifact> queue) => ArtifactsData(
    artifacts: queue,
    schedule: Schedule(
      needMinutes: 0,
      freeMinutes: 0,
      until: DateTime(2026, 10, 31),
    ),
  );

  late _MockTimelineBloc timeline;
  late _MockAgentRepository agent;
  late List<String> opened;

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
    List<TimelineEvent> backlog = const [],
    List<Artifact> queue = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => timeline.state).thenReturn(
      TimelineState(
        status: TimelineStatus.success,
        cards: cards,
        backlog: backlog,
      ),
    );

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
                  data: artifacts(queue),
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
              body: HomePage(
                onSeeDay: () => opened.add('dia'),
                onOpenLater: () => opened.add('depois'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testAt('draws the break and an empty Para depois on an empty day', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(l10n.feedBreak), findsOneWidget);
    expect(find.text(l10n.homePending), findsNothing);
    expect(find.text(l10n.homeLaterEmpty), findsOneWidget);
  });

  testAt('titles Agora by the task, its task at work under it, with pause', (
    tester,
  ) async {
    await pump(
      tester,
      cards: [
        card(
          'a',
          'Roteiro',
          TimelineSection.agora,
          at: -10,
          started: true,
          artifactId: 'p',
          artifactTitle: 'Post de novembro',
        ),
        card('b', 'Standup', TimelineSection.dia, at: 50, kind: CardKind.event),
      ],
      queue: [
        delivery('p', 'Post de novembro', startedAt: DateTime(2026, 10, 20)),
      ],
    );

    expect(top(tester, 'Post de novembro'), lessThan(top(tester, 'Roteiro')));
    final pause = tester.widget<TaskPlayButton>(
      find.byType(TaskPlayButton).first,
    );
    expect(pause.playing, isTrue);
    // The fixed block after it has no play.
    expect(find.text('Standup'), findsOneWidget);
    expect(find.byType(TaskPlayButton), findsOneWidget);
    // Agora's task is not drawn again in Pendentes.
    expect(find.text(l10n.homePending), findsNothing);

    await tester.tap(find.byType(TaskPlayButton));
    verify(() => timeline.add(const EventPauseToggled('a'))).called(1);
  });

  testAt('draws Pendentes with where each stands, its controls and bar', (
    tester,
  ) async {
    await pump(
      tester,
      queue: [
        delivery('p', 'Mapa · Renata', startedAt: DateTime(2026, 10, 20)),
      ],
    );

    expect(
      top(tester, l10n.homePending),
      lessThan(top(tester, 'Mapa · Renata')),
    );
    expect(find.textContaining('1h30 de 3h'), findsOneWidget);
    expect(find.byTooltip(l10n.controlDone), findsOneWidget);
    expect(find.byType(TaskCardBar), findsOneWidget);

    await tester.tap(find.byType(TaskPlayButton));
    verify(() => timeline.add(const ArtifactPlayed('p'))).called(1);
  });

  testAt('draws four of Para depois, loose tasks first, and opens the rest', (
    tester,
  ) async {
    await pump(
      tester,
      backlog: [
        loose('1', 'Planejar a semana'),
        loose('2', 'Notas fiscais'),
        loose('3', 'Ligar para o contador'),
        // A delivery's task waits on its page, not here.
        card(
          'x',
          'Roteiro',
          TimelineSection.backlog,
          artifactId: 'w',
          artifactTitle: 'Post',
        ),
      ],
      queue: [delivery('w', 'Post'), delivery('v', 'Mapa · Ana')],
    );

    expect(find.text('Roteiro'), findsNothing);
    expect(top(tester, 'Ligar para o contador'), lessThan(top(tester, 'Post')));
    expect(find.text('Mapa · Ana'), findsNothing);
    expect(find.text(l10n.homeLaterOpen(1)), findsOneWidget);
    expect(find.byType(TaskPlayButton), findsNWidgets(4));

    await tester.tap(find.byType(TaskPlayButton).first);
    verify(
      () => timeline.add(const EventMoved(id: '1', index: 0, start: true)),
    ).called(1);
    await tester.tap(find.byType(TaskPlayButton).last);
    verify(() => timeline.add(const ArtifactPlayed('w'))).called(1);

    await tester.tap(find.text(l10n.homeLaterOpen(1)));
    await tester.tap(find.text(l10n.feedSeeDay));
    expect(opened, ['depois', 'dia']);
  });
}
