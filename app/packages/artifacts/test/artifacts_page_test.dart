import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ArtifactsRepository {}

class _MockVoiceCubit extends MockCubit<VoiceState> implements VoiceCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(GoalKind.money);
    registerFallbackValue(GoalPeriod.month);
  });

  /// Wednesday 21 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 21, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  const mapa = CatalogType(
    id: 'mapa',
    name: 'Mapa astral',
    minutes: 180,
    price: 350,
    blockMinutes: 60,
  );
  const post = CatalogType(id: 'post', name: 'Post', minutes: 60);
  const atendimentos = CatalogCategory(
    id: 'atend',
    name: 'Atendimentos',
    types: [mapa],
  );
  const conteudo = CatalogCategory(
    id: 'cont',
    name: 'Conteúdo',
    types: [post],
  );

  Artifact artifact(
    String id,
    String title, {
    CatalogType? type,
    CatalogCategory? category,
    DateTime? doneAt,
  }) => Artifact(
    id: id,
    title: title,
    minutes: type?.minutes ?? 60,
    createdAt: DateTime(2026, 10),
    type: type,
    category: category,
    value: type?.price,
    deadline: DateTime(2026, 10, 30),
    doneAt: doneAt,
  );

  final full = ArtifactsData(
    artifacts: [
      for (var i = 1; i <= 6; i++)
        artifact(
          '$i',
          i.isEven ? 'Post $i' : 'Mapa · Cliente $i',
          type: i.isEven ? post : mapa,
          category: i.isEven ? conteudo : atendimentos,
        ),
      artifact(
        'd',
        'Mapa · Renata',
        type: mapa,
        category: atendimentos,
        doneAt: DateTime(2026, 10, 14),
      ),
    ],
    catalog: const [atendimentos, conteudo],
    goals: [
      Goal(
        id: 'g',
        kind: GoalKind.money,
        period: GoalPeriod.month,
        target: 8000,
        done: 4900,
        queued: 1230,
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
      ),
    ],
    schedule: Schedule(
      needMinutes: 11 * 60 + 15,
      freeMinutes: 26 * 60,
      until: DateTime(2026, 10, 31),
    ),
    topTypes: const [mapa],
  );
  final empty = ArtifactsData(schedule: full.schedule);

  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  Future<void> pump(WidgetTester tester, ArtifactsData data, {Widget? home}) {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The agent's bar on Todas as entregas reads the app's microphone.
    final voice = _MockVoiceCubit();
    when(() => voice.state).thenReturn(const VoiceState());

    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ArtifactsCubit(
              repository: repository,
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: data,
              ),
            ),
          ),
          BlocProvider<VoiceCubit>.value(value: voice),
        ],
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home ?? const ArtifactsPage()),
        ),
      ),
    );
  }

  /// Opens a sheet from inside the app, as the + does.
  Future<void> open(
    WidgetTester tester,
    ArtifactsData data,
    Future<void> Function(BuildContext) sheet,
  ) async {
    await pump(
      tester,
      data,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => sheet(context),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testAt('draws the goals and five of the queue', (
    tester,
  ) async {
    await pump(tester, full, home: const ArtifactsPage(showGoals: true));

    expect(
      find.text(l10n.goalInMonth(l10n.goalRevenue, 'outubro')),
      findsOneWidget,
    );
    // The agenda against the queue is not drawn any more.
    expect(find.textContaining('A fila pede'), findsNothing);
    expect(find.byType(ArtifactRow), findsNWidgets(5));
    expect(find.text(l10n.artifactsSeeAll(6)), findsOneWidget);
    expect(find.text('Mapa · Renata'), findsNothing);
  });

  testAt('keeps the queue to a shelf, or to a kind used most', (tester) async {
    await pump(tester, full);

    await tester.ensureVisible(find.text('Conteúdo'));
    await tester.pump();
    await tester.tap(find.text('Conteúdo'));
    await tester.pump();
    expect(find.byType(ArtifactRow), findsNWidgets(3));
    expect(find.text('Post 2'), findsOneWidget);
    expect(find.text('Mapa · Cliente 1'), findsNothing);

    // The kind used most comes before the shelves.
    await tester.ensureVisible(find.text('Mapa astral'));
    await tester.pump();
    await tester.tap(find.text('Mapa astral'));
    await tester.pump();
    expect(find.text('Mapa · Cliente 1'), findsOneWidget);
    expect(find.text('Post 2'), findsNothing);
  });

  testAt('starts empty, saying what a goal and the queue are for', (
    tester,
  ) async {
    await pump(tester, empty, home: const ArtifactsPage(showGoals: true));

    expect(find.text(l10n.goalsEmpty), findsOneWidget);
    expect(find.text(l10n.artifactsEmpty), findsOneWidget);
    expect(find.byType(ShelfFilter), findsNothing);
  });

  testAt('searches every delivery by name, kind or shelf', (tester) async {
    await pump(tester, full, home: const AllArtifactsPage());

    await tester.enterText(find.byType(TextField), 'renata');
    await tester.pump();
    expect(find.text(l10n.artifactsDone), findsOneWidget);
    expect(find.byType(ArtifactRow), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'conteúdo');
    await tester.pump();
    expect(find.byType(ArtifactRow), findsNWidgets(3));
  });

  testAt('puts a delivery of a kind in the queue with its blocks', (
    tester,
  ) async {
    when(
      () => repository.create(
        title: any(named: 'title'),
        typeId: any(named: 'typeId'),
        minutes: any(named: 'minutes'),
        value: any(named: 'value'),
        blockMinutes: any(named: 'blockMinutes'),
        deadline: any(named: 'deadline'),
        top: any(named: 'top'),
      ),
    ).thenAnswer((_) async => full);
    await open(tester, full, showArtifactSheet);

    await tester.tap(find.text('Mapa astral'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mapa · Ana');
    await tester.pump();
    expect(find.text(l10n.artifactTimeFromType('Mapa astral')), findsOneWidget);
    await tester.tap(find.text(l10n.artifactCreate));
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        title: 'Mapa · Ana',
        typeId: 'mapa',
        blockMinutes: 60,
        top: true,
      ),
    ).called(1);
    expect(find.byType(ArtifactSheet), findsNothing);
  });

  testAt('names a one-off in the one field, timed by hand', (tester) async {
    when(
      () => repository.create(
        title: any(named: 'title'),
        minutes: any(named: 'minutes'),
        value: any(named: 'value'),
        top: any(named: 'top'),
      ),
    ).thenAnswer((_) async => empty);
    await open(tester, empty, showArtifactSheet);

    expect(find.text(l10n.catalogEmptyTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Palestra no Sesc');
    await tester.tap(find.text(l10n.artifactSheetLoose));
    await tester.pumpAndSettle();
    expect(find.text('Palestra no Sesc'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '600');
    await tester.tap(find.text(l10n.artifactCreate));
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        title: 'Palestra no Sesc',
        minutes: 60,
        value: 600,
        top: true,
      ),
    ).called(1);
  });

  testAt('writes the first kind on a shelf it names', (tester) async {
    when(
      () => repository.addType(
        name: any(named: 'name'),
        minutes: any(named: 'minutes'),
        price: any(named: 'price'),
        blockMinutes: any(named: 'blockMinutes'),
        categoryId: any(named: 'categoryId'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((_) async => full);
    await open(tester, empty, showArtifactSheet);

    await tester.tap(find.text(l10n.catalogNewType));
    await tester.pumpAndSettle();
    expect(find.byType(TypeSheet), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(TypeSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Mapa astral');
    await tester.enterText(fields.at(1), 'Atendimentos');
    await tester.enterText(fields.at(2), '350');
    await tester.pump();
    await tester.tap(find.text(l10n.typeCreate));
    await tester.pumpAndSettle();

    verify(
      () => repository.addType(
        name: 'Mapa astral',
        minutes: 60,
        price: 350,
        category: 'Atendimentos',
      ),
    ).called(1);
    expect(find.byType(TypeSheet), findsNothing);
  });

  testAt('writes a goal of a kind, read back as a sentence', (tester) async {
    when(
      () => repository.addGoal(
        kind: any(named: 'kind'),
        target: any(named: 'target'),
        period: any(named: 'period'),
        typeId: any(named: 'typeId'),
        next: any(named: 'next'),
      ),
    ).thenAnswer((_) async => full);
    await open(
      tester,
      full,
      (context) => showGoalSheet(context, kind: GoalKind.count),
    );

    await tester.tap(find.text('Post'));
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text(l10n.goalPerWeek));
    await tester.pump();
    expect(find.text(l10n.goalReadbackCountWeek('Post', '3')), findsOneWidget);
    await tester.tap(find.text(l10n.goalCreate));
    await tester.pumpAndSettle();

    verify(
      () => repository.addGoal(
        kind: GoalKind.count,
        target: 3,
        period: GoalPeriod.week,
        typeId: 'post',
      ),
    ).called(1);
  });
}
