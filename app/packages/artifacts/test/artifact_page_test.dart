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
          child: MaterialApp(
            theme: AppTheme.current,
            locale: const Locale('pt', 'BR'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArtifactPage(id: id, dictation: dictation),
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

  testAt('Notas and Pendentes draw the bar in the same place', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // A phone with a home indicator, which lifts the floating slot.
    tester.view
      ..padding = const FakeViewPadding(bottom: 34)
      ..viewPadding = const FakeViewPadding(bottom: 34);
    await pump(tester);

    // Notas: the notes' own dock, the microphone beside the bar.
    expect(find.byType(NotesDock), findsOneWidget);
    expect(find.byType(DockHero), findsOneWidget);
    final notes = tester.getRect(find.byType(AskBar));

    await tester.tap(find.text(l10n.artifactPendingTab(2)));
    await tester.pump();

    // Pendentes: the page's floating dock, the + beside the bar, swapped in
    // where the other was.
    expect(find.byType(NotesDock), findsNothing);
    expect(find.byType(DockHero), findsOneWidget);
    expect(tester.getRect(find.byType(AskBar)), notes);
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

    // Lunna's bar and the microphone that dictates, at the foot of Notas.
    expect(find.byType(NotesDock), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Pergunte')), findsOneWidget);

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

  testAt('draws the artifact in Tempo\'s stages, and nothing else of the day', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'artifact.tab.p': 1});
    await pump(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Tarefa x'), findsNothing);
    expect(top(l10n.sectionToday), lessThan(top('Tarefa c')));
    expect(top('Tarefa c'), lessThan(top(l10n.stageBacklog)));
    expect(top(l10n.stageBacklog), lessThan(top('Tarefa d')));
    // What was done has its own tab.
    expect(find.text('Tarefa e'), findsNothing);
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
