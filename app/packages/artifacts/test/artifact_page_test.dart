import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:artifacts/artifacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeline/timeline.dart';

class _MockRepository extends Mock implements ArtifactsRepository {}

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

class _MockVoiceCubit extends MockCubit<VoiceState> implements VoiceCubit {}

/// A recognizer the test speaks through.
class _FakeRecognizer implements VoiceRecognizer {
  late VoiceWords _onWords;

  @override
  Future<VoiceAvailability> prepare() async => VoiceAvailability.available;

  @override
  Future<void> listen({
    required VoiceWords onWords,
    required ValueChanged<double> onLevel,
    required VoidCallback onEnd,
  }) async => _onWords = onWords;

  void say(String words, {bool done = false}) => _onWords(words, done: done);

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  setUpAll(() => registerFallbackValue(const TimelineRequested()));

  /// Ten in the morning, wherever this runs: the screen reads [clock].
  final now = DateTime(2026, 6, 10, 10);

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  final l10n = lookupAppLocalizations(const Locale('pt'));

  ArtifactTask task(String id, TaskPlace place, {DateTime? doneAt}) =>
      ArtifactTask(
        id: id,
        title: 'Tarefa $id',
        minutes: 30,
        place: place,
        notes: 'Notas de $id',
        doneAt: doneAt,
      );

  final artifact = Artifact(
    id: 'p',
    title: 'Site do estúdio',
    minutes: 90,
    createdAt: DateTime(2026, 6),
    deadline: DateTime(2026, 6, 24),
    tasks: [
      task('c', TaskPlace.queue),
      task('d', TaskPlace.backlog),
      task('e', TaskPlace.done, doneAt: DateTime(2026, 6, 10, 9)),
    ],
  );

  TimelineEvent card(String id, int fromMinutes) => TimelineEvent(
    id: id,
    title: 'Tarefa $id',
    section: TimelineSection.dia,
    startTime: now.add(Duration(minutes: fromMinutes)),
    endTime: now.add(Duration(minutes: fromMinutes + 30)),
    durationMinutes: 30,
  );

  final day = TimelineState(
    status: TimelineStatus.success,
    cards: [card('x', 30), card('c', 65)],
    tasks: [card('x', 30), card('c', 65)],
    backlog: [
      TimelineEvent.fromJson({
        'id': 'd',
        'kind': 'task',
        'title': 'Tarefa d',
        'section': 'backlog',
        'durationMinutes': 30,
        'workMinutes': 30,
      }),
    ],
  );

  ArtifactsData data(List<Artifact> artifacts) => ArtifactsData(
    artifacts: artifacts,
    schedule: Schedule(
      needMinutes: 0,
      freeMinutes: 0,
      until: DateTime(2026, 6, 30),
    ),
  );

  late _MockRepository repository;
  late _MockTimelineBloc timeline;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.load()).thenAnswer((_) async => data([artifact]));
    timeline = _MockTimelineBloc();
    when(() => timeline.state).thenReturn(day);
  });

  Future<void> pump(
    WidgetTester tester, {
    String id = 'p',
    DictationCubit? dictation,
    Artifact? shown,
    ComposeOpener? compose,
    Widget? page,
  }) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = _MockVoiceCubit();
    when(() => voice.state).thenReturn(const VoiceState());

    await tester.pumpWidget(
      RepositoryProvider<VoiceRecognizer>.value(
        value: _FakeRecognizer(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<TimelineBloc>.value(value: timeline),
            BlocProvider<VoiceCubit>.value(value: voice),
            BlocProvider(
              create: (_) => ArtifactsCubit(
                repository: repository,
                initial: ArtifactsState(
                  status: ArtifactsStatus.ready,
                  data: data([shown ?? artifact]),
                ),
              ),
            ),
          ],
          child: ComposeLauncher(
            open: compose ?? (_, {about}) async {},
            child: MaterialApp(
              theme: AppTheme.current,
              locale: const Locale('pt', 'BR'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: page ?? ArtifactPage(id: id, dictation: dictation),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testAt('opens on the notes, then on whatever was last chosen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.text(l10n.artifactNotesHint), findsOneWidget);

    await tester.tap(find.text(l10n.artifactPendingTab(2)));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getInt('artifact.tab.p'),
      1,
    );

    await tester.tap(find.text(l10n.artifactDoneTab(1)));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getInt('artifact.tab.p'),
      2,
    );
  });

  testAt('draws the bar Entregas draws, work over time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    expect(find.byType(PaceBars), findsOneWidget);
  });

  testAt('Notas and Pendentes draw the + in the same place', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // A phone with a home indicator, which lifts the floating slot.
    tester.view
      ..padding = const FakeViewPadding(bottom: 34)
      ..viewPadding = const FakeViewPadding(bottom: 34);
    await pump(tester);

    // Notas: the notes' own dock, the microphone beside the bar.
    expect(find.byType(NotesDock), findsOneWidget);
    expect(find.byType(DockHero), findsOneWidget);
    final compose = find.byTooltip(l10n.composeOpen);
    final notes = tester.getRect(compose);

    await tester.tap(find.text(l10n.artifactPendingTab(2)));
    await tester.pump();

    // Pendentes: the page's floating dock, the + beside the bar, swapped in
    // where the other was.
    expect(find.byType(NotesDock), findsNothing);
    expect(find.byType(DockHero), findsOneWidget);
    expect(tester.getRect(compose), notes);
  });

  testAt('dictates into the notes, a paragraph each time, saved as typed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final saved = <String>[];
    when(
      () => repository.update(any(), notes: any(named: 'notes')),
    ).thenAnswer((call) async {
      final notes = call.namedArguments[#notes] as String;
      saved.add(notes);
      // The server's echo of what was saved.
      return data([artifact.copyWith(notes: notes)]);
    });
    final recognizer = _FakeRecognizer();
    final dictation = DictationCubit(recognizer: recognizer);
    addTearDown(dictation.close);
    await pump(tester, dictation: dictation);

    // The composer's + and the microphone that dictates, at the foot of
    // Notas.
    expect(find.byType(NotesDock), findsOneWidget);
    expect(find.byTooltip(l10n.composeOpen), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.dictationStart));
    await tester.pump();
    recognizer.say('Paleta em tons de terra');
    await tester.pump(const Duration(seconds: 1));

    TextEditingController notes() => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((it) => it.controller)
        .whereType<LiveTextController>()
        .single;
    expect(notes().text, 'Paleta em tons de terra');
    expect(saved, ['Paleta em tons de terra']);

    // The echo lands mid-dictation and takes nothing away.
    recognizer.say('Paleta em tons de terra e verde');
    await tester.pump();
    expect(notes().text, 'Paleta em tons de terra e verde');

    await tester.tap(find.bySemanticsLabel(l10n.dictationStop));
    await tester.pump(const Duration(seconds: 1));
    expect(saved.last, 'Paleta em tons de terra e verde');

    // A second recording is a paragraph of its own.
    await tester.tap(find.byTooltip(l10n.dictationStart));
    await tester.pump();
    recognizer.say('Revisar com a Ana');
    await tester.pump();
    expect(
      notes().text,
      'Paleta em tons de terra e verde\n\nRevisar com a Ana',
    );
    await tester.tap(find.bySemanticsLabel(l10n.dictationStop));
    await tester.pump(const Duration(seconds: 1));
  });

  testAt('draws its tasks under Para depois, each with play, and nothing '
      'else of the day', (tester) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
    await pump(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Tarefa x'), findsNothing);
    expect(find.text(l10n.feedNow), findsNothing);
    expect(top(l10n.stageBacklog), lessThan(top('Tarefa c')));
    expect(top('Tarefa c'), lessThan(top('Tarefa d')));
    expect(find.byType(TaskPlayButton), findsNWidgets(2));
    // What was done has its own tab.
    expect(find.text('Tarefa e'), findsNothing);

    // Play on a subtask asks by play's rules (#89): when, then (it fits)
    // nothing more.
    await tester.tap(find.byType(TaskPlayButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.playWhenNow));
    await tester.pumpAndSettle();
    verify(
      () => timeline.add(const EventMoved(id: 'd', index: 0, start: true)),
    ).called(1);
  });

  testAt('opens on the notes when nothing is pending, and an empty '
      "Pendentes offers the home's Adicionar, about this task", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
    AgentSubject? asked;
    var opened = 0;
    await pump(
      tester,
      shown: Artifact(
        id: 'p',
        title: 'Site do estúdio',
        minutes: 90,
        createdAt: DateTime(2026, 6),
        tasks: [task('e', TaskPlace.done, doneAt: DateTime(2026, 6, 10, 9))],
      ),
      compose: (_, {about}) async {
        opened++;
        asked = about;
      },
    );
    expect(find.text(l10n.artifactNotesHint), findsOneWidget);

    await tester.tap(find.text(l10n.artifactPendingTab(0)));
    await tester.pump();
    expect(find.byType(AppAddRow), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppAddRow),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    expect(opened, 1);
    expect(asked, isNotNull);
  });

  group('a subtask', () {
    final timed = Artifact(
      id: 'p',
      title: 'Site do estúdio',
      minutes: 90,
      createdAt: DateTime(2026, 6),
      tasks: [
        ArtifactTask(
          id: 'c',
          title: 'Tarefa c',
          minutes: 30,
          place: TaskPlace.queue,
          at: now.add(const Duration(minutes: 65)),
        ),
        task('d', TaskPlace.backlog),
      ],
    );

    testAt('swiped left asks, and only yes deletes it', (tester) async {
      SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
      await pump(tester);

      await tester.drag(find.text('Tarefa d'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.confirmDeleteSubtaskBody), findsOneWidget);
      // Tapping outside is a no.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text(l10n.confirmDeleteSubtaskBody), findsNothing);
      verifyNever(() => timeline.add(any(that: isA<EventDeleted>())));

      await tester.drag(find.text('Tarefa d'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirmDeleteAction));
      await tester.pumpAndSettle();
      verify(() => timeline.add(const EventDeleted('d'))).called(1);
    });

    testAt('swiped right is ticked off at once; a short swipe does nothing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
      await pump(tester);

      await tester.drag(find.text('Tarefa d'), const Offset(40, 0));
      await tester.pumpAndSettle();
      verifyNever(() => timeline.add(any(that: isA<EventFinished>())));

      await tester.drag(find.text('Tarefa d'), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.confirmDeleteAction), findsNothing);
      verify(() => timeline.add(const EventFinished('d'))).called(1);
    });

    testAt('held and dragged above another takes its place in the day', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
      await pump(tester, shown: timed);

      final from = tester.getCenter(find.text('Tarefa d'));
      final to = tester.getCenter(find.text('Tarefa c'));
      final finger = await tester.startGesture(from);
      await tester.pump(
        const Duration(milliseconds: 500) + const Duration(milliseconds: 100),
      );
      for (var i = 1; i <= 10; i++) {
        await finger.moveTo(
          Offset(from.dx, from.dy + (to.dy - from.dy - 20) * i / 10),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
      await finger.up();
      await tester.pumpAndSettle();

      // It settles where it was let go, before the day answers (#118).
      expect(
        tester.getCenter(find.text('Tarefa d')).dy,
        lessThan(tester.getCenter(find.text('Tarefa c')).dy),
      );
      // Before c, which has an hour: c's place in the day's tasks.
      verify(
        () => timeline.add(const EventMoved(id: 'd', index: 1)),
      ).called(1);
    });

    test('a move lands in the queue or the backlog, as its neighbour', () {
      final c = timed.tasks[0];
      final d = timed.tasks[1];
      // Before a task with an hour: its place in the queue.
      expect(
        subtaskMove('d', [c], 0, day),
        const EventMoved(id: 'd', index: 1),
      );
      // After the last one, which waits in the backlog: right under it.
      expect(
        subtaskMove('c', [d], 1, day),
        const EventMoved(id: 'c', index: 1, backlog: true),
      );
      // Before one waiting in the backlog: its place there.
      expect(
        subtaskMove('c', [d], 0, day),
        const EventMoved(id: 'c', index: 0, backlog: true),
      );
      // Nothing it knows on the day: no move.
      expect(subtaskMove('d', [task('z', TaskPlace.backlog)], 0, day), isNull);
    });
  });

  testAt('a loose task opens on the three tabs, Pendentes an Adicionar', (
    tester,
  ) async {
    await pump(tester, page: const TaskPage(id: 'x'));

    expect(find.text(l10n.artifactNotesTab), findsOneWidget);
    expect(find.text(l10n.artifactDoneTab(0)), findsOneWidget);
    await tester.tap(find.text(l10n.artifactPendingTab(0)));
    await tester.pump();
    expect(find.byType(AppAddRow), findsOneWidget);
  });

  testAt('draws its task running on Agora, with pause, over the rest', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
    final running = TimelineEvent(
      id: 'c',
      title: 'Tarefa c',
      section: TimelineSection.agora,
      started: true,
      startTime: now.subtract(const Duration(minutes: 10)),
      endTime: now.add(const Duration(minutes: 20)),
      durationMinutes: 30,
      workMinutes: 30,
      artifactId: 'p',
      artifactTitle: 'Site do estúdio',
    );
    when(() => timeline.state).thenReturn(
      TimelineState(
        status: TimelineStatus.success,
        cards: [running],
        tasks: [running],
        backlog: day.backlog,
      ),
    );
    await pump(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top(l10n.feedNow), lessThan(top('Tarefa c')));
    expect(top('Tarefa c'), lessThan(top(l10n.stageBacklog)));
    expect(top(l10n.stageBacklog), lessThan(top('Tarefa d')));
    final pause = tester.widget<TaskPlayButton>(
      find.byType(TaskPlayButton).first,
    );
    expect(pause.playing, isTrue);

    await tester.tap(find.byType(TaskPlayButton).first);
    verify(() => timeline.add(const EventPauseToggled('c'))).called(1);
  });

  testAt('keeps what was done in Feitas, newest first, under its day', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 2});
    final older = artifact.copyWith(
      tasks: [
        ...artifact.tasks,
        task('f', TaskPlace.done, doneAt: DateTime(2026, 6, 9, 15)),
        task('g', TaskPlace.done, doneAt: DateTime(2026, 6, 10, 9, 30)),
      ],
    );
    when(() => repository.load()).thenAnswer((_) async => data([older]));
    await pump(tester, shown: older);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Tarefa c'), findsNothing);
    expect(top(l10n.archiveToday), lessThan(top('Tarefa g')));
    expect(top('Tarefa g'), lessThan(top('Tarefa e')));
    expect(top('Tarefa e'), lessThan(top(l10n.archiveYesterday)));
    expect(top(l10n.archiveYesterday), lessThan(top('Tarefa f')));
    // Nothing names the delivery: the page does.
    expect(find.byType(AppTag), findsNothing);
  });

  testAt('opens a finished task on its notes, saying when it was done', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 2});
    await pump(tester);

    await tester.tap(find.text('Tarefa e'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Notas de e'), findsOneWidget);
    expect(
      find.text(l10n.eventDoneOn(l10n.dayToday.toLowerCase(), '09:00')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppIconButton && widget.iconData == AppIcons.trash,
      ),
      findsNothing,
    );
  });

  testAt('says what it is, and marks it delivered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    when(
      () => repository.update(any(), done: any(named: 'done')),
    ).thenAnswer(
      (_) async => data([artifact.copyWith(doneAt: () => now)]),
    );
    await pump(tester);

    expect(find.text('${l10n.artifactLoose} · 1h30'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppIconButton && widget.iconData == AppIcons.check,
      ),
    );
    await tester.pump();

    verify(() => repository.update('p', done: true)).called(1);
    expect(
      find.text(l10n.artifactDoneOn(l10n.dayToday.toLowerCase())),
      findsOneWidget,
    );
  });

  testAt('gives it a value from its row, and takes it away', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final priced = Artifact(
      id: 'p',
      title: 'Site do estúdio',
      minutes: 90,
      createdAt: DateTime(2026, 6),
      value: 400,
    );
    when(
      () => repository.update(any(), value: any(named: 'value')),
    ).thenAnswer((invocation) async {
      final value = invocation.namedArguments[#value] as int? Function();
      return data([
        if (value() == null) artifact else priced,
      ]);
    });
    await pump(tester);

    await tester.tap(find.text(l10n.artifactValueAdd));
    await tester.pumpAndSettle();
    expect(find.byType(ValueSheet), findsOneWidget);
    // Nothing typed, nothing to save, and nothing to take away.
    expect(find.text(l10n.artifactValueClear), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byType(ValueSheet),
        matching: find.byType(TextField),
      ),
      '400',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();
    final saved =
        verify(
              () => repository.update('p', value: captureAny(named: 'value')),
            ).captured.single
            as int? Function();
    expect(saved(), 400);
    expect(find.text(r'R$ 400'), findsOneWidget);

    await tester.tap(find.text(r'R$ 400'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.artifactValueClear));
    await tester.pumpAndSettle();
    final cleared =
        verify(
              () => repository.update('p', value: captureAny(named: 'value')),
            ).captured.single
            as int? Function();
    expect(cleared(), isNull);
    expect(find.text(l10n.artifactValueAdd), findsOneWidget);
  });

  testAt('reads the artifact again when the day changes', (tester) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
    whenListen(
      timeline,
      Stream.value(day.copyWith(backlog: const [])),
      initialState: day,
    );
    await pump(tester);

    verify(() => repository.load()).called(1);
  });
}
