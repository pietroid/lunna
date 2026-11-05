import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/plan/view/plan_drag.dart';
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
    int minutes = 45,
  }) {
    final start = now.add(Duration(minutes: at));
    return TimelineEvent(
      id: id,
      title: title,
      section: section,
      kind: kind,
      started: started,
      startTime: start,
      endTime: start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
      workMinutes: minutes,
      artifactId: artifactId,
      artifactTitle: artifactTitle,
    );
  }

  TimelineEvent loose(
    String id,
    String title, {
    bool pending = false,
    int minutes = 45,
  }) {
    final start = now;
    return TimelineEvent(
      id: id,
      title: title,
      section: TimelineSection.backlog,
      startTime: start,
      endTime: start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
      workMinutes: minutes,
      pending: pending,
    );
  }

  Artifact delivery(
    String id,
    String title, {
    DateTime? startedAt,
    DateTime? deadline,
    bool noDeadline = false,
    int minutes = 180,
    List<ArtifactTask> tasks = const [
      ArtifactTask(
        id: 't',
        title: 'Roteiro',
        minutes: 30,
        place: TaskPlace.backlog,
      ),
    ],
  }) => Artifact(
    id: id,
    title: title,
    minutes: minutes,
    doneMinutes: 90,
    createdAt: DateTime(2026, 10),
    deadline: noDeadline ? null : deadline ?? DateTime(2026, 11, 3),
    startedAt: startedAt,
    tasks: tasks,
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
    List<TimelineEvent> tasks = const [],
    List<Artifact> queue = const [],
    ArtifactsRepository? artifactsRepository,
    TimelineStatus status = TimelineStatus.success,
  }) async {
    tester.view
      ..physicalSize = const Size(600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => timeline.state).thenReturn(
      TimelineState(
        status: status,
        cards: cards,
        tasks: tasks,
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
                repository: artifactsRepository ?? _MockArtifactsRepository(),
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

  /// Plays with [play]: answers the first sheet, when ([PlayWhenQuestion]),
  /// with [button], then, with [pause], yes to pausing what runs
  /// ([PauseQuestion]), then how much, with [piece].
  Future<void> playWith(
    WidgetTester tester,
    Finder play,
    String button, {
    String? piece,
    bool pause = false,
  }) async {
    // Agora's card keeps moving while a task runs: pumped, not settled.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(play);
    await settle();
    expect(find.byType(PlayWhenQuestion), findsOneWidget);
    // Only when: two answers, no pieces.
    expect(find.text(formatMinutes(l10n, kPlayPieces.first)), findsNothing);
    await tester.tap(find.textContaining(button));
    await settle();
    if (pause) {
      expect(find.byType(PauseQuestion), findsOneWidget);
      await tester.tap(find.text(l10n.guardPauseYes));
      await settle();
    }
    if (piece != null) {
      expect(find.byType(PlayWhenQuestion), findsNothing);
      await tester.tap(find.text(piece));
      await settle();
    }
  }

  testAt('draws the skeleton of each section until the day first arrives', (
    tester,
  ) async {
    await pump(tester, status: TimelineStatus.initial);

    expect(find.byType(PlanSkeletonCard), findsWidgets);
    expect(find.byType(AgoraIdleTile), findsNothing);
    expect(find.text(l10n.feedNow), findsOneWidget);
    expect(find.text(l10n.feedNext), findsOneWidget);
    expect(find.text(l10n.homeSeeCalendar), findsOneWidget);
    expect(find.text(l10n.stageBacklog), findsOneWidget);
    expect(find.text(l10n.homePending), findsNothing);
  });

  testAt('draws the break and an empty Para depois on an empty day', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(AgoraIdleTile), findsOneWidget);
    expect(find.text(l10n.homePending), findsNothing);
    expect(find.text(l10n.homeLaterEmpty), findsOneWidget);
    expect(find.text(l10n.homeNextEmpty), findsOneWidget);
    expect(find.byType(PlanSkeletonCard), findsNothing);
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

    expect(
      tester.getTopLeft(find.text('Post de novembro').first).dy,
      lessThan(tester.getTopLeft(find.text('Roteiro').first).dy),
    );
    final pause = tester.widget<TaskPlayButton>(
      find.byType(TaskPlayButton).first,
    );
    expect(pause.playing, isTrue);
    // The fixed block after it has no play.
    expect(find.text('Standup'), findsOneWidget);
    // Its delivery stays in Pendentes (#92), where the rest of it waits:
    // the piece at work is the yellow after the green.
    expect(find.text(l10n.homePending), findsOneWidget);
    expect(find.text('Post de novembro'), findsNWidgets(2));
    expect(find.byType(TaskPlayButton), findsNWidgets(2));
    final bar = tester
        .widgetList<TaskCardBar>(find.byType(TaskCardBar))
        .map((it) => it.bar)
        .singleWhere((it) => it.pace);
    expect(bar.done, 0.5);
    expect(bar.doing, greaterThan(0));

    await tester.tap(find.byType(TaskPlayButton).first);
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

    // Its next task is not on the day and is short: nothing to ask.
    await tester.tap(find.byType(TaskPlayButton));
    await tester.pump();
    expect(find.byType(PlayWhenQuestion), findsNothing);
    verify(() => timeline.add(const ArtifactPlayed('p'))).called(1);
  });

  testAt('draws the whole of Para depois, loose tasks first, then its +', (
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
    expect(top(tester, 'Post'), lessThan(top(tester, 'Mapa · Ana')));
    expect(find.byType(TaskPlayButton), findsNWidgets(5));
    // Em seguida's + and Para depois's, the last thing on the page.
    expect(find.byType(AppAddRow), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byType(AppAddRow).last).dy,
      greaterThan(top(tester, 'Mapa · Ana')),
    );

    await playWith(tester, find.byType(TaskPlayButton).first, l10n.playWhenNow);
    verify(
      () => timeline.add(const EventMoved(id: '1', index: 0, start: true)),
    ).called(1);

    await tester.tap(find.text(l10n.homeSeeCalendar));
    expect(opened, ['dia']);
  });

  testAt('its + writes into the backlog', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.timelineAdd).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppPromptSheet), findsOneWidget);
  });

  testAt('draws a loose task paused off the day in Pendentes, not later', (
    tester,
  ) async {
    await pump(
      tester,
      backlog: [
        loose('1', 'Notas fiscais', pending: true),
        loose('2', 'Planejar a semana'),
      ],
    );

    expect(
      top(tester, l10n.homePending),
      lessThan(top(tester, 'Notas fiscais')),
    );
    expect(
      top(tester, 'Notas fiscais'),
      lessThan(top(tester, l10n.stageBacklog)),
    );
    expect(
      top(tester, l10n.stageBacklog),
      lessThan(top(tester, 'Planejar a semana')),
    );
    expect(find.text(l10n.pendingTaskLeft('45 min')), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.controlDone));
    verify(() => timeline.add(const EventFinished('1'))).called(1);
  });

  testAt('marks a pending task past its day urgent, the day in the corner', (
    tester,
  ) async {
    await pump(
      tester,
      queue: [
        delivery(
          'p',
          'Relatório',
          startedAt: DateTime(2026, 10, 20),
          deadline: DateTime(2026, 10, 27),
        ),
        delivery(
          'q',
          'Proposta',
          startedAt: DateTime(2026, 10, 20),
          deadline: DateTime(2026, 10, 29),
        ),
      ],
    );

    expect(find.text(l10n.dueYesterday), findsOneWidget);
    expect(find.text('quinta-feira'), findsOneWidget);
    expect(find.textContaining('Urgente'), findsOneWidget);
    // The urgent one first.
    expect(top(tester, 'Relatório'), lessThan(top(tester, 'Proposta')));
    // −1d +1d move the day.
    expect(find.byTooltip(l10n.controlDayEarlier), findsNWidgets(2));
  });

  testAt(
    'asks only how much for a delivery with no tasks, and begins a piece',
    (
      tester,
    ) async {
      await pump(
        tester,
        queue: [
          delivery(
            'p',
            'Proposta',
            startedAt: DateTime(2026, 10, 20),
            minutes: 240,
            tasks: const [],
          ),
        ],
      );

      await tester.tap(find.byType(TaskPlayButton));
      await tester.pumpAndSettle();
      // No task to queue: there is no when to ask.
      expect(find.byType(PlayWhenQuestion), findsNothing);
      // Measured against the room up to the day's end.
      expect(find.text(l10n.playMuchNowTitle), findsOneWidget);
      expect(find.text(l10n.playWhole('2h30')), findsOneWidget);

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      verify(
        () => timeline.add(const ArtifactPlayed('p', minutes: 30)),
      ).called(1);
    },
  );

  testAt('asks when for the next task of a delivery, and queues a piece', (
    tester,
  ) async {
    await pump(
      tester,
      backlog: [
        card(
          't',
          'Gravação',
          TimelineSection.backlog,
          minutes: 90,
          artifactId: 'p',
          artifactTitle: 'Vídeo',
        ),
      ],
      queue: [
        delivery(
          'p',
          'Vídeo',
          startedAt: DateTime(2026, 10, 20),
          tasks: const [
            ArtifactTask(
              id: 't',
              title: 'Gravação',
              minutes: 90,
              place: TaskPlace.backlog,
            ),
          ],
        ),
      ],
    );

    await tester.tap(find.byType(TaskPlayButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.playWhenTitle('Gravação')), findsOneWidget);
    await tester.tap(find.text(l10n.playWhenNow));
    await tester.pumpAndSettle();
    // Over an hour: the second sheet asks how much, of the subtask.
    expect(find.text(l10n.playMuchNowTitle), findsOneWidget);
    await tester.tap(find.text(l10n.playWhole('1h30')));
    await tester.pumpAndSettle();
    verify(
      () => timeline.add(const EventMoved(id: 't', index: 0, start: true)),
    ).called(1);

    // Nothing runs: the later hour is 15 minutes from now, an anchor.
    await playWith(
      tester,
      find.byType(TaskPlayButton),
      l10n.playWhenSoon('10:15'),
      piece: '1h',
    );
    verify(
      () => timeline.add(
        EventMoved(
          id: 't',
          index: 0,
          after: DateTime(2026, 10, 28, 10, 15),
          minutes: 60,
          split: true,
        ),
      ),
    ).called(1);
  });

  Future<void> carry(WidgetTester tester, Finder from, Finder to) async {
    final gesture = await tester.startGesture(tester.getCenter(from));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(to) + const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testAt('carries a task of Para depois to Agora, which begins it', (
    tester,
  ) async {
    await pump(tester, backlog: [loose('1', 'Notas fiscais')]);

    await carry(
      tester,
      find.text('Notas fiscais'),
      find.byType(AgoraIdleTile),
    );

    verify(
      () => timeline.add(const EventMoved(id: '1', index: 0, start: true)),
    ).called(1);
  });

  testAt('carries the running task into Pendentes without asking', (
    tester,
  ) async {
    await pump(
      tester,
      cards: [
        card('a', 'Roteiro', TimelineSection.agora, at: -10, started: true),
      ],
      backlog: [loose('1', 'Notas fiscais')],
    );

    // Pendentes is empty, so it shows itself only once something is held.
    expect(find.text(l10n.homePending), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Roteiro')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 5));
    await tester.pump();
    expect(find.text(l10n.homePending), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text(l10n.homePending)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    // Agora's card keeps moving, so the page never settles.
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => timeline.add(
        const EventMoved(id: 'a', index: 0, backlog: true, pending: true),
      ),
    ).called(1);
  });

  testAt('draws only the green bar for a pending task with no day (#92)', (
    tester,
  ) async {
    await pump(
      tester,
      queue: [
        delivery(
          'p',
          'Mapa · Renata',
          startedAt: DateTime(2026, 10, 20),
          noDeadline: true,
        ),
      ],
    );

    final bar = tester.widget<TaskCardBar>(find.byType(TaskCardBar)).bar;
    expect(bar.pace, isTrue);
    expect(bar.time, isNull);
    expect(bar.doing, 0);
    final fills = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(TaskCardBar),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((it) => it.color);
    expect(fills, contains(AppColors.paceDone));
    expect(fills, isNot(contains(AppColors.paceTime)));
    expect(fills, isNot(contains(AppColors.accent)));
  });

  testAt('carries a pending loose task back to Para depois (#92)', (
    tester,
  ) async {
    await pump(
      tester,
      backlog: [
        loose('1', 'Notas fiscais', pending: true),
        loose('2', 'Planejar a semana'),
      ],
    );

    await carry(
      tester,
      find.text('Notas fiscais'),
      find.text(l10n.stageBacklog),
    );

    verify(
      () => timeline.add(const EventMoved(id: '1', index: 0, backlog: true)),
    ).called(1);
  });

  testAt('carries a pending delivery to Para depois, which stops it', (
    tester,
  ) async {
    final repository = _MockArtifactsRepository();
    when(
      () => repository.move(any(), any(), stop: any(named: 'stop')),
    ).thenAnswer((_) async => artifacts([delivery('p', 'Mapa')]));
    await pump(
      tester,
      queue: [delivery('p', 'Mapa', startedAt: DateTime(2026, 10, 20))],
      artifactsRepository: repository,
    );

    await carry(tester, find.text('Mapa'), find.text(l10n.stageBacklog));

    verify(() => repository.move('p', 0, stop: true)).called(1);
  });

  testWidgets(
    'says the day is over outside the working day, as the calendar does',
    (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 23)), () async {
        await pump(tester);

        expect(find.byType(DayOverTile), findsOneWidget);
        expect(find.byType(FreeTile), findsNothing);
      });
    },
  );

  testAt('draws Em seguida from its start to its end, with play', (
    tester,
  ) async {
    await pump(
      tester,
      cards: [
        card('a', 'Roteiro', TimelineSection.agora, at: -10, started: true),
        card('b', 'Planejar a semana', TimelineSection.dia, at: 40),
      ],
    );

    expect(find.text(l10n.feedNext), findsOneWidget);
    expect(find.text('10:40 – 11:25'), findsOneWidget);
    expect(find.byType(TaskPlayButton), findsNWidgets(2));
    // Ver calendário sits beside Em seguida's heading.
    expect(
      top(tester, l10n.homeSeeCalendar),
      closeTo(top(tester, l10n.feedNext), 12),
    );

    // Now, with a task running: the pause is asked, and answered on the
    // move itself.
    await playWith(
      tester,
      find.byType(TaskPlayButton).last,
      l10n.playWhenNow,
      pause: true,
    );
    verify(
      () => timeline.add(
        const EventMoved(
          id: 'b',
          index: 0,
          start: true,
          decision: TimingDecision.pauseCurrent,
        ),
      ),
    ).called(1);

    // Later: right after what runs, at the end of its pause.
    await playWith(
      tester,
      find.byType(TaskPlayButton).last,
      l10n.playWhenAfter('Roteiro', '10:40'),
    );
    verify(() => timeline.add(const EventMoved(id: 'b', index: 0))).called(1);
  });

  group('Em seguida', () {
    final day = [
      card('a', 'Roteiro', TimelineSection.agora, at: -10, started: true),
      card('b', 'Planejar a semana', TimelineSection.dia, at: 40),
      card('c', 'Standup', TimelineSection.dia, at: 90, kind: CardKind.event),
      card('d', 'Responder e-mails', TimelineSection.dia, at: 140),
      card('e', 'Revisar contrato', TimelineSection.dia, at: 190),
      card('f', 'Ligar para a gráfica', TimelineSection.dia, at: 240),
    ];

    testAt('draws every card of the day, events too, then + Adicionar', (
      tester,
    ) async {
      await pump(tester, cards: day);

      expect(find.text(l10n.feedNext), findsOneWidget);
      for (final title in [
        'Planejar a semana',
        'Standup',
        'Responder e-mails',
        'Revisar contrato',
        'Ligar para a gráfica',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        top(tester, 'Revisar contrato'),
        lessThan(top(tester, 'Ligar para a gráfica')),
      );
      // Agora's pause and a play on each task; the event has the pin.
      expect(find.byType(TaskPlayButton), findsNWidgets(5));
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIcon && w.iconData == AppIcons.pin,
        ),
        findsOneWidget,
      );
      expect(find.byType(AppAddRow), findsWidgets);
      final add = tester.widget<AppAddRow>(find.byType(AppAddRow).first);
      expect(add.dense, isTrue);
      expect(find.text(l10n.homeNextEmpty), findsNothing);
    });

    testAt('runs on into the tasks of the next days, under their day', (
      tester,
    ) async {
      final tomorrow = card(
        'g',
        'Fechar o mês',
        TimelineSection.dia,
        at: 24 * 60,
      );
      final friday = card(
        'h',
        'Planejar novembro',
        TimelineSection.dia,
        at: 2 * 24 * 60,
      );
      await pump(
        tester,
        cards: day,
        tasks: [
          for (final c in day)
            if (c.isTask) c,
          tomorrow,
          friday,
        ],
      );

      expect(find.text(l10n.sectionTomorrow), findsOneWidget);
      expect(
        top(tester, 'Ligar para a gráfica'),
        lessThan(top(tester, l10n.sectionTomorrow)),
      );
      expect(
        top(tester, l10n.sectionTomorrow),
        lessThan(top(tester, 'Fechar o mês')),
      );
      expect(find.textContaining('30 de outubro'), findsOneWidget);
      expect(
        top(tester, 'Fechar o mês'),
        lessThan(top(tester, 'Planejar novembro')),
      );
    });

    testAt('+ Adicionar opens the sheet to write one down', (tester) async {
      await pump(tester, cards: day);

      await tester.tap(find.text(l10n.timelineAdd).first);
      // The sheet's field blinks its cursor: pumped, not settled.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppPromptSheet), findsOneWidget);
    });

    testAt('play over an hour asks how much, and when', (tester) async {
      await pump(
        tester,
        cards: [
          card('b', 'Escrever o roteiro', TimelineSection.dia, minutes: 120),
        ],
      );

      await playWith(
        tester,
        find.byType(TaskPlayButton),
        l10n.playWhenNow,
        piece: formatMinutes(l10n, 30),
      );
      verify(
        () => timeline.add(
          const EventMoved(id: 'b', index: 0, start: true, minutes: 30),
        ),
      ).called(1);

      await playWith(
        tester,
        find.byType(TaskPlayButton),
        l10n.playWhenSoon('10:15'),
        piece: formatMinutes(l10n, 60),
      );
      verify(
        () => timeline.add(
          EventMoved(
            id: 'b',
            index: 0,
            after: DateTime(2026, 10, 28, 10, 15),
            minutes: 60,
            split: true,
          ),
        ),
      ).called(1);
    });

    testAt('a task over an hour let go in it asks how much goes there', (
      tester,
    ) async {
      final b = card('b', 'Planejar a semana', TimelineSection.dia, at: 40);
      await pump(
        tester,
        cards: [b],
        tasks: [b],
        backlog: [loose('1', 'Escrever o roteiro', minutes: 120)],
      );

      await carry(
        tester,
        find.text('Escrever o roteiro'),
        find.text('Planejar a semana'),
      );
      expect(find.byType(PlayMuchQuestion), findsOneWidget);
      expect(find.text(l10n.playMuchAtTitle('10:05')), findsOneWidget);

      await tester.tap(find.text(formatMinutes(l10n, 30)));
      await tester.pumpAndSettle();
      verify(
        () => timeline.add(
          const EventMoved(id: '1', index: 0, minutes: 30, split: true),
        ),
      ).called(1);
    });

    test('its + writes right after the last task it draws', () {
      final tasks = [
        for (final c in day)
          if (c.isTask) c,
      ];
      PlanItems items(List<TimelineEvent> cards) => PlanItems.of(
        TimelineState(cards: cards, tasks: tasks),
        null,
        now,
      );

      // Every card drawn: after f, the last of a b d e f.
      expect(queueEndOf(tasks, items(day)), 5);
      // The last drawn an event: after the task above it.
      expect(queueEndOf(tasks, items(day.take(3).toList())), 2);
      // Nothing in Em seguida: right under what runs.
      expect(queueEndOf(tasks, items(day.take(1).toList())), 1);
    });
  });
}
