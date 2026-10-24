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

  group('progressGroups', () {
    // Created on 1 October, due at the end of the 31st: on the 21st, two
    // thirds of the time are gone.
    final due = DateTime(2026, 10, 31);

    test('puts what is under way first, the most behind on top', () {
      final groups = progressGroups([
        artifact('fresh'),
        artifact(
          'ahead',
          deadline: due,
          tasks: [step('1', done: true), step('2', done: true), step('3')],
        ),
        artifact('waiting', deadline: due),
        artifact(
          'behind',
          deadline: due,
          tasks: [step('1', done: true), step('2'), step('3'), step('4')],
        ),
        artifact('worked', doneMinutes: 20),
      ], now);

      expect(
        [for (final a in groups.started) a.id],
        [
          'behind',
          'ahead',
          'worked',
        ],
      );
      // Not begun keeps the queue's order, whatever the deadlines say.
      expect([for (final a in groups.waiting) a.id], ['fresh', 'waiting']);
    });

    test('breaks a tie in lag by the queue order', () {
      final groups = progressGroups([
        artifact('b', doneMinutes: 30),
        artifact('a', doneMinutes: 30),
      ], now);
      expect([for (final a in groups.started) a.id], ['b', 'a']);
    });
  });

  group('queueIndexOf', () {
    // The queue: two under way between the ones not begun.
    final queue = [
      artifact('w1'),
      artifact('s1', doneMinutes: 10),
      artifact('w2'),
      artifact('s2', doneMinutes: 10),
      artifact('w3'),
    ];
    final waiting = [queue[0], queue[2], queue[4]];

    test('lands before the row it was let go above', () {
      // w3 to the top of Não iniciadas: before w1.
      expect(queueIndexOf(queue, waiting, 'w3', 0), 0);
      // w1 between w2 and w3: before w3, counted without w1.
      expect(queueIndexOf(queue, waiting, 'w1', 1), 3);
    });

    test('lands after the last row when let go at the end', () {
      expect(queueIndexOf(queue, waiting, 'w1', 2), 4);
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
          artifact(
            'semana',
            deadline: DateTime(2026, 10, 25),
            tasks: [step('1', done: true), step('2')],
          ),
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

    testWidgets('heads what is under way above what is not begun', (
      tester,
    ) async {
      await pumpPage(tester);

      final started = find.text(l10n.artifactsInProgress);
      final waiting = find.text(l10n.artifactsNotStarted);
      expect(started, findsOneWidget);
      expect(waiting, findsOneWidget);
      // Under way, though it is due later: the heading is the work, not
      // the day.
      final going = find.text('Entrega semana');
      final fresh = find.text('Entrega hoje');
      expect(
        tester.getTopLeft(started).dy,
        lessThan(tester.getTopLeft(going).dy),
      );
      expect(
        tester.getTopLeft(going).dy,
        lessThan(tester.getTopLeft(waiting).dy),
      );
      expect(
        tester.getTopLeft(waiting).dy,
        lessThan(tester.getTopLeft(fresh).dy),
      );
      expect(
        tester.widget<Text>(started).style?.fontSize,
        AppTypography.title.fontSize,
      );
      // Only what is not begun is dragged.
      expect(
        find.byType(ReorderableDelayedDragStartListener),
        findsOneWidget,
      );
    });
  });
}
