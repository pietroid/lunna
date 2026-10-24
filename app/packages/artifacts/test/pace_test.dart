import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ArtifactsRepository {}

void main() {
  /// Wednesday 21 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 21, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  ArtifactTask step(String id, {bool done = false}) => ArtifactTask(
    id: id,
    title: 'Etapa $id',
    minutes: 30,
    place: done ? TaskPlace.done : TaskPlace.queue,
  );

  Artifact artifact(
    String id, {
    DateTime? deadline,
    DateTime? createdAt,
    List<ArtifactTask> tasks = const [],
    int minutes = 60,
    int doneMinutes = 0,
  }) => Artifact(
    id: id,
    title: 'Entrega $id',
    minutes: minutes,
    doneMinutes: doneMinutes,
    createdAt: createdAt ?? DateTime(2026, 10),
    deadline: deadline,
    tasks: tasks,
  );

  group('dueOf', () {
    test('heads each delivery by the day it is due', () {
      Due due(DateTime? deadline) =>
          dueOf(artifact('a', deadline: deadline), now);

      expect(due(DateTime(2026, 10, 19)), Due.today, reason: 'overdue');
      expect(due(DateTime(2026, 10, 21)), Due.today);
      expect(due(DateTime(2026, 10, 22)), Due.tomorrow);
      expect(due(DateTime(2026, 10, 28)), Due.week, reason: 'day 7');
      expect(due(DateTime(2026, 10, 29)), Due.later, reason: 'day 8');
      expect(due(null), Due.none);
    });
  });

  group('byDue', () {
    test('puts the soonest first, none last, ties in the queue order', () {
      final sorted = byDue([
        artifact('none'),
        artifact('week', deadline: DateTime(2026, 10, 25)),
        artifact('today', deadline: DateTime(2026, 10, 21)),
        artifact('week-too', deadline: DateTime(2026, 10, 25)),
        artifact('late', deadline: DateTime(2026, 10, 20)),
      ], now);

      expect(
        [for (final a in sorted) a.id],
        ['late', 'today', 'week', 'week-too', 'none'],
      );
    });
  });

  group('workDone', () {
    test('counts the tasks done out of the tasks', () {
      final a = artifact(
        'a',
        tasks: [
          step('1', done: true),
          step('2', done: true),
          step('3'),
          step('4'),
        ],
      );
      expect(workDone(a), 0.5);
    });

    test('counts the minutes worked when it has no tasks', () {
      expect(workDone(artifact('a', minutes: 120, doneMinutes: 30)), 0.25);
      expect(workDone(artifact('b', minutes: 0)), 0);
    });
  });

  group('isBehind', () {
    // Written on the 1st, due on the 9th of November: a little over half
    // the time gone on the 21st.
    final deadline = DateTime(2026, 11, 9);
    List<ArtifactTask> done(int of10) => [
      for (var i = 0; i < 10; i++) step('$i', done: i < of10),
    ];

    test('is on pace within the slack', () {
      final time = artifact('a', deadline: deadline).progressAt(now)!;
      final tasks = done(((time - paceSlack) * 10).ceil());
      expect(
        isBehind(artifact('a', deadline: deadline, tasks: tasks), now),
        isFalse,
      );
    });

    test('is behind past the slack', () {
      final time = artifact('a', deadline: deadline).progressAt(now)!;
      final tasks = done(((time - paceSlack) * 10).floor() - 1);
      expect(
        isBehind(artifact('a', deadline: deadline, tasks: tasks), now),
        isTrue,
      );
    });

    test('is never behind without a deadline', () {
      expect(isBehind(artifact('a', tasks: done(0)), now), isFalse);
    });
  });

  group('PaceBars', () {
    Future<void> pumpBars(WidgetTester tester, Artifact a) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaceBars(artifact: a, now: now),
        ),
      ),
    );

    Iterable<Color> fills(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).color!);

    testWidgets('draws no red without a deadline', (tester) async {
      await pumpBars(tester, artifact('a', tasks: [step('1', done: true)]));

      expect(fills(tester), [AppColors.paceDone]);
    });

    testWidgets('draws the green over the red', (tester) async {
      await pumpBars(
        tester,
        artifact('a', deadline: DateTime(2026, 10, 30), tasks: [step('1')]),
      );

      expect(fills(tester), [AppColors.paceTime, AppColors.paceDone]);
    });

    testWidgets('writes the end in the danger ink once it is late', (
      tester,
    ) async {
      final late = artifact('a', deadline: DateTime(2026, 10, 19));
      await pumpBars(tester, late);

      final text = tester.widgetList<Text>(find.byType(Text)).last;
      expect(text.style?.color, AppColors.dangerInk);
    });
  });

  group('Entregas', () {
    Future<void> pumpAt(WidgetTester tester, {bool showGoals = false}) {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final data = ArtifactsData(
        artifacts: [
          artifact('hoje', deadline: DateTime(2026, 10, 21)),
          artifact('semana', deadline: DateTime(2026, 10, 25)),
        ],
        goals: [
          Goal(
            id: 'g',
            kind: GoalKind.money,
            period: GoalPeriod.month,
            target: 8000,
            start: DateTime(2026, 10),
            end: DateTime(2026, 11),
          ),
        ],
        schedule: Schedule(
          needMinutes: 60,
          freeMinutes: 600,
          until: DateTime(2026, 10, 31),
        ),
      );

      return tester.pumpWidget(
        BlocProvider(
          create: (_) => ArtifactsCubit(
            repository: _MockRepository(),
            initial: ArtifactsState(status: ArtifactsStatus.ready, data: data),
          ),
          child: MaterialApp(
            theme: AppTheme.current,
            locale: const Locale('pt', 'BR'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ArtifactsPage(showGoals: showGoals)),
          ),
        ),
      );
    }

    // The page reads the day from `clock`, so its due days are counted
    // from the test's Wednesday, not from the machine's.
    Future<void> pumpPage(WidgetTester tester, {bool showGoals = false}) =>
        withClock(
          Clock.fixed(now),
          () => pumpAt(tester, showGoals: showGoals),
        );

    testWidgets('hides the goals unless asked to', (tester) async {
      await pumpPage(tester);
      expect(find.text(l10n.goalsSection), findsNothing);
      expect(find.text(l10n.goalNew), findsNothing);

      await pumpPage(tester, showGoals: true);
      expect(find.text(l10n.goalsSection), findsOneWidget);
    });

    testWidgets('heads the deliveries by due day, as the timeline heads days', (
      tester,
    ) async {
      await pumpPage(tester);

      final today = find.text(l10n.artifactsDueToday);
      final week = find.text(l10n.artifactsDueWeek);
      expect(today, findsOneWidget);
      expect(week, findsOneWidget);
      expect(
        tester.getTopLeft(today).dy,
        lessThan(tester.getTopLeft(find.text('Entrega hoje')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Entrega hoje')).dy,
        lessThan(tester.getTopLeft(week).dy),
      );
      expect(
        tester.widget<Text>(today).style?.fontSize,
        AppTypography.title.fontSize,
      );
    });
  });
}
