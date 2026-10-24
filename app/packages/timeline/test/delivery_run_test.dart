import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

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

  TimelineEvent task(
    String id,
    int fromMinutes,
    int minutes, {
    String? artifact,
    TimelineSection section = TimelineSection.dia,
    String notes = '',
  }) => TimelineEvent(
    id: id,
    title: 'Tarefa $id',
    section: section,
    startTime: now.add(Duration(minutes: fromMinutes)),
    endTime: now.add(Duration(minutes: fromMinutes + minutes)),
    durationMinutes: minutes,
    started: section == TimelineSection.agora,
    notes: notes,
    artifactId: artifact,
    artifactTitle: artifact == null ? null : 'Entrega $artifact',
  );

  final shelved = TimelineEvent.fromJson({
    'id': 'x',
    'kind': 'task',
    'title': 'Armário',
    'section': 'backlog',
    'durationMinutes': 45,
    'workMinutes': 45,
  });

  Future<(TimelineBloc, List<TimelineEvent>)> pump(
    WidgetTester tester, {
    required List<TimelineEvent> tasks,
    List<TimelineEvent> backlog = const [],
    TimelineMode mode = TimelineMode.list,
  }) async {
    final bloc = _MockTimelineBloc();
    when(() => bloc.state).thenReturn(
      TimelineState(
        status: TimelineStatus.success,
        cards: tasks,
        tasks: tasks,
        backlog: backlog,
      ),
    );
    final tapped = <TimelineEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.current,
        home: Scaffold(
          body: BlocProvider<TimelineBloc>.value(
            value: bloc,
            child: TimelineList(onCardTap: tapped.add, mode: mode),
          ),
        ),
      ),
    );
    await tester.pump();

    return (bloc as TimelineBloc, tapped);
  }

  group('deliveryRuns', () {
    test('joins only the tasks of one delivery that follow each other', () {
      final runs = deliveryRuns([
        task('a', 0, 30, artifact: 'p'),
        task('b', 35, 30, artifact: 'p'),
        task('c', 70, 30),
        task('d', 105, 30, artifact: 'p'),
        task('e', 140, 30, artifact: 'q'),
      ]);

      expect(
        [
          for (final run in runs) [for (final card in run) card.id],
        ],
        [
          ['a', 'b'],
          ['c'],
          ['d'],
          ['e'],
        ],
      );
    });

    test('never joins two that the caller refuses', () {
      final runs = deliveryRuns(
        [task('a', 0, 30, artifact: 'p'), task('b', 90, 30, artifact: 'p')],
        joins: (before, after) =>
            after.startTime.difference(before.endTime).inMinutes <= 10,
      );

      expect(runs, hasLength(2));
    });
  });

  group('Lista', () {
    final running = task('a', -10, 30, section: TimelineSection.agora);
    final run = [
      task('p1', 25, 30, artifact: 'p'),
      task('p2', 60, 40, artifact: 'p'),
    ];
    final after = task('c', 105, 30);

    testAt('draws a run as one card: the delivery, and its next task', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      await pump(tester, tasks: [running, ...run, after]);

      expect(find.byType(DeliveryTile), findsOneWidget);
      expect(find.text('Entrega p'), findsOneWidget);
      expect(find.text('Tarefa p1'), findsOneWidget);
      expect(find.text('Tarefa p2'), findsNothing);
      // The tag under each task is gone: the card names the delivery.
      expect(find.byType(AppTag), findsNothing);
      expect(find.text(l10n.sectionNow), findsOneWidget);
      expect(find.text(l10n.sectionToday), findsOneWidget);
      expect(find.text(l10n.stageBacklog), findsOneWidget);
    });

    testAt('opens the next task on a tap on the card', (tester) async {
      final (_, tapped) = await pump(tester, tasks: [running, ...run, after]);

      await tester.tap(find.text('Entrega p'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tapped.single.id, 'p1');
    });

    testAt('drops under the card after the whole run', (tester) async {
      final (bloc, _) = await pump(
        tester,
        tasks: [running, ...run, after],
        backlog: [shelved],
      );

      final card = tester.getRect(find.byType(DeliveryTile));
      final from = tester.getCenter(find.text('Armário'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 350));
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(
          Offset.lerp(from, Offset(from.dx, card.bottom + 2), step / 8)!,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => bloc.add(const EventMoved(id: 'x', index: 3))).called(1);
    });

    testAt('draws the running run in Agora, with one bar for all of it', (
      tester,
    ) async {
      await pump(
        tester,
        tasks: [
          task('a', -10, 30, artifact: 'p', section: TimelineSection.agora),
          ...run,
        ],
      );

      expect(find.byType(DeliveryTile), findsOneWidget);
      expect(find.byType(RunBar), findsOneWidget);
      expect(find.text('Tarefa a'), findsOneWidget);
      // The rest of the run is in the bar, not in lines of its own.
      expect(find.text('Tarefa p1'), findsNothing);
    });
  });

  group('Calendário', () {
    testAt('draws a run as one block with a line per task', (tester) async {
      final run = [
        task('p1', 25, 30, artifact: 'p'),
        task('p2', 60, 40, artifact: 'p'),
      ];
      final (_, tapped) = await pump(
        tester,
        tasks: run,
        mode: TimelineMode.calendar,
      );

      expect(find.byType(DeliveryTile), findsOneWidget);
      expect(find.text('Tarefa p1'), findsOneWidget);
      expect(find.text('Tarefa p2'), findsOneWidget);
      // As tall as the two blocks one under the other.
      expect(
        tester.getSize(find.byType(DeliveryTile)).height,
        closeTo(
          run.fold<double>(
                0,
                (sum, it) => sum + TimelineScale.blockHeight(it),
              ) +
              AppSpacing.s1,
          0.5,
        ),
      );

      // Each line is its task.
      await tester.tap(find.text('Tarefa p2'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped.single.id, 'p2');
    });

    testAt('keeps apart a run with room drawn in between', (tester) async {
      await pump(
        tester,
        tasks: [
          task('p1', 25, 30, artifact: 'p'),
          task('p2', 120, 30, artifact: 'p'),
        ],
        mode: TimelineMode.calendar,
      );

      expect(find.byType(DeliveryTile), findsNothing);
      expect(find.byType(EventTile), findsNWidgets(2));
    });
  });

  group('DeliveryTile', () {
    Future<void> pumpTile(WidgetTester tester, DeliveryTile tile) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.current,
          home: Scaffold(body: Center(child: tile)),
        ),
      );
    }

    final three = [
      task('p1', 30, 15, artifact: 'p'),
      task('p2', 50, 15, artifact: 'p'),
      task('p3', 70, 15, artifact: 'p'),
    ];

    testAt('in Lista draws one line, the next task', (tester) async {
      await pumpTile(tester, DeliveryTile(title: 'Entrega p', tasks: three));

      expect(find.text('Tarefa p1'), findsOneWidget);
      expect(find.text('Tarefa p2'), findsNothing);
    });

    testAt('on the calendar draws every line where they fit', (tester) async {
      await pumpTile(
        tester,
        DeliveryTile(title: 'Entrega p', tasks: three, height: 200),
      );

      for (final title in ['Tarefa p1', 'Tarefa p2', 'Tarefa p3']) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testAt('falls back to the next task where they do not', (tester) async {
      await pumpTile(
        tester,
        DeliveryTile(title: 'Entrega p', tasks: three, height: 80),
      );

      expect(find.text('Tarefa p1'), findsOneWidget);
      expect(find.text('Tarefa p2'), findsNothing);
    });

    testAt('shows a lone task with the start of its notes', (tester) async {
      await pumpTile(
        tester,
        DeliveryTile(
          title: 'Entrega p',
          tasks: [task('p1', 30, 60, artifact: 'p', notes: 'Rever o roteiro')],
          height: 140,
        ),
      );

      expect(find.text('Tarefa p1'), findsOneWidget);
      expect(find.text('Rever o roteiro'), findsOneWidget);
    });
  });
}
