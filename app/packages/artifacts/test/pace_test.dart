import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
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
    DateTime? startedAt,
    List<ArtifactTask> tasks = const [],
    int minutes = 60,
    int doneMinutes = 0,
  }) => Artifact(
    id: id,
    title: 'Entrega $id',
    minutes: minutes,
    doneMinutes: doneMinutes,
    createdAt: createdAt ?? DateTime(2026, 10),
    startedAt: startedAt,
    deadline: deadline,
    tasks: tasks,
  );

  /// Begun on the 1st, so on the 21st two thirds of the time to the end of
  /// the 30th are gone.
  final begun = DateTime(2026, 10);

  group('progressGroups', () {
    final due = DateTime(2026, 10, 30);

    test('puts what was begun first, the urgent and then the most behind '
        'on top', () {
      final groups = progressGroups([
        artifact('fresh', doneMinutes: 50),
        artifact('ahead', startedAt: begun, deadline: due, doneMinutes: 50),
        artifact('waiting', deadline: due),
        // Two thirds of the time gone, a little over half the work done:
        // within the slack, so behind the rest but not urgent.
        artifact('close', startedAt: begun, deadline: due, doneMinutes: 35),
        artifact('behind', startedAt: begun, deadline: due, doneMinutes: 10),
        artifact('worked', startedAt: begun, doneMinutes: 20),
        // Its day is gone, so it is urgent, though it lags less.
        artifact(
          'overdue',
          startedAt: begun,
          deadline: DateTime(2026, 10, 20),
          doneMinutes: 55,
        ),
      ], now);

      expect(
        [for (final a in groups.started) a.id],
        [
          'behind',
          'overdue',
          'close',
          'ahead',
          'worked',
        ],
      );
      // Not begun keeps the queue's order, whatever was done of it.
      expect([for (final a in groups.waiting) a.id], ['fresh', 'waiting']);
    });

    test('breaks a tie in lag by the queue order', () {
      final groups = progressGroups([
        artifact('b', startedAt: begun, doneMinutes: 30),
        artifact('a', startedAt: begun, doneMinutes: 30),
      ], now);
      expect([for (final a in groups.started) a.id], ['b', 'a']);
    });
  });

  group('isUrgent', () {
    test('is only for what was begun, past its day or behind', () {
      final overdue = DateTime(2026, 10, 20);
      expect(isUrgent(artifact('a', deadline: overdue), now), isFalse);
      expect(
        isUrgent(artifact('b', startedAt: begun, deadline: overdue), now),
        isTrue,
      );
      expect(
        isUrgent(
          artifact(
            'c',
            startedAt: begun,
            deadline: DateTime(2026, 10, 30),
            doneMinutes: 10,
          ),
          now,
        ),
        isTrue,
      );
      expect(isUrgent(artifact('d', startedAt: begun), now), isFalse);
    });
  });

  group('queueIndexOf', () {
    // The queue: two under way between the ones not begun.
    final queue = [
      artifact('w1'),
      artifact('s1', startedAt: begun),
      artifact('w2'),
      artifact('s2', startedAt: begun),
      artifact('w3'),
    ];
    final waiting = [queue[0], queue[2], queue[4]];

    test('lands before the row it was let go above', () {
      // w3 to the top of Não iniciadas: before w1.
      expect(queueIndexOf(queue, waiting, 'w3', 0), 0);
      // w1 between w2 and w3: before w3, counted without w1.
      expect(queueIndexOf(queue, waiting, 'w1', 1), 3);
      // s1, stopped, dropped above w2: before it.
      expect(queueIndexOf(queue, waiting, 's1', 1), 1);
    });

    test('lands after the last row when let go at the end', () {
      expect(queueIndexOf(queue, waiting, 'w1', 2), 4);
    });
  });

  group('workDone', () {
    test('counts the minutes done out of the whole time', () {
      // One task of 15 minutes of four, done: a twelfth of three hours,
      // not a quarter.
      final a = artifact(
        'a',
        minutes: 180,
        doneMinutes: 15,
        tasks: [
          step('1', done: true),
          step('2'),
          step('3'),
          step('4'),
        ],
      );
      expect(workDone(a), closeTo(1 / 12, 1e-9));
      expect(workDone(artifact('b', minutes: 120, doneMinutes: 30)), 0.25);
      expect(workDone(artifact('c', minutes: 0)), 0);
    });
  });

  group('isBehind', () {
    // Begun on the 1st, due on the 9th of November: a little over half
    // the time gone on the 21st.
    final deadline = DateTime(2026, 11, 9);
    Artifact worked(int of100) => artifact(
      'a',
      startedAt: begun,
      deadline: deadline,
      minutes: 100,
      doneMinutes: of100,
    );

    test('is on pace within the slack', () {
      final time = worked(0).progressAt(now)!;
      expect(isBehind(worked(((time - paceSlack) * 100).ceil()), now), isFalse);
    });

    test('is behind past the slack', () {
      final time = worked(0).progressAt(now)!;
      expect(
        isBehind(worked(((time - paceSlack) * 100).floor() - 1), now),
        isTrue,
      );
    });

    test('is never behind without a deadline, or not begun', () {
      expect(isBehind(artifact('a', startedAt: begun), now), isFalse);
      expect(isBehind(artifact('b', deadline: deadline), now), isFalse);
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
      await pumpBars(tester, artifact('a', startedAt: begun, doneMinutes: 30));

      expect(fills(tester), [AppColors.paceDone]);
    });

    testWidgets('draws the green over the red, keyed by time and day', (
      tester,
    ) async {
      await pumpBars(
        tester,
        artifact(
          'a',
          startedAt: begun,
          deadline: DateTime(2026, 10, 30),
          minutes: 180,
          doneMinutes: 60,
        ),
      );

      expect(fills(tester), [AppColors.paceTime, AppColors.paceDone]);
      expect(
        find.text(
          l10n.artifactTimeDone(l10n.durationHours(1), l10n.durationHours(3)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('writes the end in the danger ink once it is late', (
      tester,
    ) async {
      final late = artifact(
        'a',
        startedAt: begun,
        deadline: DateTime(2026, 10, 19),
      );
      await pumpBars(tester, late);

      final text = tester.widgetList<Text>(find.byType(Text)).last;
      expect(text.style?.color, AppColors.dangerInk);
    });
  });

  group('Entregas', () {
    late _MockRepository repository;

    setUp(() => repository = _MockRepository());

    final schedule = Schedule(
      needMinutes: 60,
      freeMinutes: 600,
      until: DateTime(2026, 10, 31),
    );

    final defaults = [
      artifact('hoje', deadline: DateTime(2026, 10, 21)),
      artifact(
        'semana',
        startedAt: begun,
        deadline: DateTime(2026, 10, 25),
        doneMinutes: 55,
      ),
    ];

    Future<void> pumpAt(
      WidgetTester tester, {
      bool showGoals = false,
      List<Artifact>? artifacts,
    }) {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final data = ArtifactsData(
        artifacts: artifacts ?? defaults,
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
        schedule: schedule,
      );

      return tester.pumpWidget(
        BlocProvider(
          create: (_) => ArtifactsCubit(
            repository: repository,
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
    Future<void> pumpPage(
      WidgetTester tester, {
      bool showGoals = false,
      List<Artifact>? artifacts,
    }) => withClock(
      Clock.fixed(now),
      () => pumpAt(tester, showGoals: showGoals, artifacts: artifacts),
    );

    /// Holds [title]'s row and lets it go [by] below where it was.
    Future<void> drag(WidgetTester tester, String title, Offset by) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(title)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(by / 10);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('hides the goals unless asked to', (tester) async {
      await pumpPage(tester);
      expect(find.text(l10n.goalsSection), findsNothing);
      expect(find.text(l10n.goalNew), findsNothing);

      await pumpPage(tester, showGoals: true);
      expect(find.text(l10n.goalsSection), findsOneWidget);
    });

    testWidgets('heads what was begun above what was not', (tester) async {
      await pumpPage(tester);

      final started = find.text(l10n.artifactsInProgress);
      final waiting = find.text(l10n.artifactsNotStarted);
      expect(started, findsOneWidget);
      expect(waiting, findsOneWidget);
      // Begun, though it is due later: the heading is the clock, not the
      // day.
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
      // Both groups drag, and each ends in a +.
      expect(
        find.byType(ReorderableDelayedDragStartListener),
        findsNWidgets(2),
      );
      expect(find.byType(AppAddRow), findsNWidgets(2));
    });

    testWidgets('heads an empty Em andamento, a place to drop on', (
      tester,
    ) async {
      await pumpPage(tester, artifacts: [defaults.first]);

      expect(find.text(l10n.artifactsInProgress), findsOneWidget);
      expect(find.text(l10n.artifactsNotStarted), findsOneWidget);
      expect(find.byType(AppAddRow), findsNWidgets(2));
    });

    testWidgets('draws a late one first, tinted and tagged Urgente, with '
        'no line under its name', (tester) async {
      await pumpPage(
        tester,
        artifacts: [
          ...defaults,
          artifact(
            'atrasada',
            startedAt: begun,
            deadline: DateTime(2026, 10, 30),
            minutes: 180,
            doneMinutes: 15,
          ),
        ],
      );

      expect(find.text(l10n.artifactUrgent), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Entrega atrasada')).dy,
        lessThan(tester.getTopLeft(find.text('Entrega semana')).dy),
      );
      final card = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Entrega atrasada'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, AppColors.urgentFill);
      // The day it is due is the red's key, in the danger ink.
      expect(
        tester
            .widget<Text>(find.text(l10n.artifactUntil('sex, 30 out')))
            .style
            ?.color,
        AppColors.dangerInk,
      );
      expect(find.byType(PaceBars), findsNWidgets(2));
    });

    testWidgets('begins one dragged up that has a day', (tester) async {
      when(
        () => repository.update(
          'hoje',
          started: true,
          deadline: any(named: 'deadline'),
        ),
      ).thenAnswer((_) async => ArtifactsData(schedule: schedule));
      await pumpPage(tester);

      await drag(tester, 'Entrega hoje', const Offset(0, -160));

      verify(
        () => repository.update(
          'hoje',
          started: true,
          deadline: any(named: 'deadline'),
        ),
      ).called(1);
    });

    testWidgets('asks the day of one dragged up with none, and closing the '
        'sheet leaves it', (tester) async {
      await pumpPage(tester, artifacts: [defaults.last, artifact('solta')]);

      await drag(tester, 'Entrega solta', const Offset(0, -160));
      expect(find.text(l10n.artifactStartTitle('Entrega solta')), findsOne);

      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text(l10n.artifactStartTitle('Entrega solta')), findsNothing);
      verifyNever(
        () => repository.update(
          any(),
          started: any(named: 'started'),
          deadline: any(named: 'deadline'),
        ),
      );
    });

    testWidgets('stops one dragged down, at the place it was let go', (
      tester,
    ) async {
      when(
        () => repository.move('semana', any(), stop: true),
      ).thenAnswer((_) async => ArtifactsData(schedule: schedule));
      await pumpPage(tester);

      await drag(tester, 'Entrega semana', const Offset(0, 260));

      verify(() => repository.move('semana', 1, stop: true)).called(1);
    });
  });
}
