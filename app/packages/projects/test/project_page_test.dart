import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:projects/projects.dart';

class _MockRepository extends Mock implements ProjectsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(TaskPlace.project));

  /// Ten in the morning, wherever this runs: the screen reads [clock].
  final now = DateTime(2026, 6, 10, 10);

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  ProjectTask task(String id, TaskPlace place, {DateTime? at}) => ProjectTask(
    id: id,
    title: 'Tarefa $id',
    minutes: 30,
    place: place,
    at: at,
  );

  final project = Project(
    id: 'p',
    title: 'Site do estúdio',
    createdAt: DateTime(2026, 6),
    deadline: DateTime(2026, 6, 24),
    tasks: [
      task('a', TaskPlace.project),
      task('b', TaskPlace.project),
      task('c', TaskPlace.queue, at: DateTime(2026, 6, 10, 14)),
      task('d', TaskPlace.backlog),
      task('e', TaskPlace.done),
    ],
  );

  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(
      () => repository.placeTask(
        any(),
        any(),
        any(),
        at: any(named: 'at'),
        index: any(named: 'index'),
      ),
    ).thenAnswer((_) async => [project]);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ProjectsCubit(
          repository: repository,
          initial: ProjectsState(
            status: ProjectsStatus.ready,
            projects: [project],
          ),
        ),
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProjectPage(id: 'p'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testAt('files the tasks under where they are, as Lista does', (
    tester,
  ) async {
    await pump(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Só no projeto'), lessThan(top('Tarefa a')));
    expect(top('Tarefa b'), lessThan(top('Fazer em breve')));
    expect(top('Fazer em breve'), lessThan(top('Tarefa c')));
    expect(top('Depois eu priorizo'), lessThan(top('Tarefa d')));
    expect(top('1 feita'), lessThan(top('Tarefa e')));
    // On the day, a card reads its hours; off it, its length.
    expect(find.text('14:00–14:30'), findsOneWidget);
    expect(find.text('faltam 14 dias'), findsOneWidget);
  });

  testAt('asks where a tapped task goes, and moves it there', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Tarefa a'));
    await tester.pumpAndSettle();
    expect(find.text('Onde fica esta tarefa?'), findsOneWidget);

    await tester.tap(find.text('Fazer em breve').last);
    await tester.pumpAndSettle();

    verify(
      () => repository.placeTask('p', 'a', TaskPlace.queue),
    ).called(1);
  });

  testAt('moves a card dragged into another stage', (tester) async {
    await pump(tester);

    final from = tester.getCenter(find.text('Tarefa a'));
    final to = tester.getCenter(find.text('Tarefa d'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    verify(
      () => repository.placeTask('p', 'a', TaskPlace.backlog),
    ).called(1);
  });

  testAt('reorders the project by dropping a card on another', (
    tester,
  ) async {
    await pump(tester);

    final from = tester.getCenter(find.text('Tarefa b'));
    final to = tester.getCenter(find.text('Tarefa a'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    verify(
      () => repository.placeTask('p', 'b', TaskPlace.project, index: 0),
    ).called(1);
  });
}
