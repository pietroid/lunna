import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ArtifactsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  /// Wednesday 28 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 28, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  /// R$ 10.000 from 1 October to 30 November, R$ 2.850 in.
  Goal running({int done = 2850, int queued = 0, int queuedCount = 0}) => Goal(
    id: 'nov',
    kind: GoalKind.money,
    target: 10000,
    done: done,
    queued: queued,
    queuedCount: queuedCount,
    start: DateTime(2026, 10),
    end: DateTime(2026, 12),
  );

  final next = Goal(
    id: 'dez',
    kind: GoalKind.money,
    target: 12000,
    start: DateTime(2026, 12),
    end: DateTime(2027),
  );
  final september = Goal(
    id: 'set',
    kind: GoalKind.money,
    target: 8000,
    done: 8650,
    start: DateTime(2026, 9),
    end: DateTime(2026, 10),
  );

  ArtifactsData data(List<Goal> goals) => ArtifactsData(
    goals: goals,
    schedule: Schedule(
      needMinutes: 0,
      freeMinutes: 0,
      until: DateTime(2026, 10, 31),
    ),
  );

  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  Future<void> pump(WidgetTester tester, List<Goal> goals) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider(
        // A cubit of its own each time, so a second pump draws its goals.
        key: UniqueKey(),
        create: (_) => ArtifactsCubit(
          repository: repository,
          initial: ArtifactsState(
            status: ArtifactsStatus.ready,
            data: data(goals),
          ),
        ),
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: GoalsPage()),
        ),
      ),
    );
  }

  group('the days offered', () {
    test("are next week's Sunday and next month's last day", () {
      final offered = goalSuggestions(DateTime(2026, 10, 28));
      expect(offered.week, DateTime(2026, 11, 8));
      expect(offered.month, DateTime(2026, 11, 30));
      // From a Sunday, the week after is the next one's.
      expect(goalSuggestions(DateTime(2026, 11)).week, DateTime(2026, 11, 8));
    });

    test('count from where the running goal ends, or from today', () {
      expect(goalStartAfter(const [], now), DateTime(2026, 10, 28));
      expect(goalStartAfter([september], now), DateTime(2026, 10, 28));
      expect(goalStartAfter([september, running()], now), DateTime(2026, 12));
    });
  });

  testAt('says what a goal is before there is one', (tester) async {
    await pump(tester, const []);

    expect(find.text(l10n.goalsEmptyTitle), findsOneWidget);
    await tester.tap(find.text(l10n.goalsNew));
    await tester.pumpAndSettle();
    expect(find.byType(GoalSheet), findsOneWidget);
  });

  testAt('writes a goal by next month, or by the day picked', (tester) async {
    when(
      () => repository.addGoal(
        target: any(named: 'target'),
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async => data([running()]));
    await pump(tester, const []);
    await tester.tap(find.text(l10n.goalsNew));
    await tester.pumpAndSettle();

    // Nothing typed, nothing to write.
    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, l10n.goalCreateObjective),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pump();
    expect(
      find.text(l10n.goalReadbackBy(r'R$ 10.000', '30 nov')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.goalByNextWeek));
    await tester.pump();
    expect(
      find.text(l10n.goalReadbackBy(r'R$ 10.000', '8 nov')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.goalByNextMonth));
    await tester.pump();
    await tester.tap(find.text(l10n.goalCreateObjective));
    await tester.pumpAndSettle();

    verify(
      () => repository.addGoal(target: 10000, deadline: DateTime(2026, 11, 30)),
    ).called(1);
    expect(find.byType(GoalSheet), findsNothing);
  });

  testAt('a goal written while one runs starts where it ends', (tester) async {
    await pump(tester, [running()]);
    showGoalSheet(tester.element(find.byType(GoalsPage))).ignore();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12000');
    await tester.pump();

    // Next month, counted from 1 December: the end of January.
    expect(
      find.text(l10n.goalReadbackBy(r'R$ 12.000', '31 jan')),
      findsOneWidget,
    );
    expect(find.textContaining('ter, 1 dez'), findsOneWidget);
  });

  testAt('draws the running goal, the next and the past', (tester) async {
    await pump(tester, [september, running(), next]);

    expect(find.byType(GoalCard), findsNWidgets(2));
    expect(find.text(l10n.goalsUpcoming), findsOneWidget);
    expect(find.text(l10n.goalsPast), findsOneWidget);
    expect(find.byType(GoalRow), findsOneWidget);
    expect(find.text(l10n.goalReached), findsOneWidget);
    expect(find.byType(PaceBar), findsNWidgets(2));
  });

  testAt('reads on pace up to 15 % behind, and behind past it', (
    tester,
  ) async {
    final expected = running().expectedAt(now);

    await pump(tester, [running(done: expected - 1500)]);
    expect(find.text(l10n.goalOnPace), findsOneWidget);

    await pump(tester, [running(done: expected - 1501)]);
    expect(find.text(l10n.goalBehind(r'R$ 1.501')), findsOneWidget);

    await pump(tester, [running(done: expected + 200)]);
    expect(find.text(l10n.goalAhead(r'R$ 200')), findsOneWidget);
  });

  testAt('says where the open deliveries take it', (tester) async {
    await pump(tester, [running(queued: 1050, queuedCount: 3)]);
    expect(
      find.text(l10n.goalQueuedLine(3, 'R\u0024\u00a03.900', '30 nov')),
      findsOneWidget,
    );

    await pump(tester, [running(queued: 7150, queuedCount: 9)]);
    expect(find.text(l10n.goalQueuedReaches(9, '30 nov')), findsOneWidget);

    // With nothing due by its day, no line.
    await pump(tester, [running()]);
    expect(find.textContaining('entrega'), findsNothing);
  });

  testAt('opens a goal to change its amount', (tester) async {
    when(
      () => repository.updateGoal(
        any(),
        target: any(named: 'target'),
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async => data([running()]));
    await pump(tester, [running()]);

    await tester.tap(find.byType(GoalCard));
    await tester.pumpAndSettle();
    expect(find.text(l10n.goalEditTitle), findsOneWidget);
    expect(find.text(l10n.goalByNextMonth), findsNothing);
    expect(find.textContaining('Conta desde qui, 1 out'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12000');
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();

    verify(() => repository.updateGoal('nov', target: 12000)).called(1);
  });
}
