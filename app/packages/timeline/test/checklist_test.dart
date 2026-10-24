import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineRepository extends Mock implements TimelineRepository {}

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const TimelineRequested());
    registerFallbackValue(CardKind.task);
  });

  /// Ten in the morning, wherever this runs.
  final now = DateTime(2026, 6, 10, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  /// Breakfast, a flexible routine's day with a list of three, the first
  /// [done] of them ticked off.
  TimelineEvent breakfast({
    int done = 0,
    TimelineSection section = TimelineSection.dia,
    CardKind kind = CardKind.task,
  }) => TimelineEvent(
    id: 'b',
    title: 'Café da manhã',
    section: section,
    kind: kind,
    startTime: now.add(const Duration(hours: 1)),
    endTime: now.add(const Duration(hours: 2)),
    durationMinutes: 60,
    routine: 'daily',
    notes: 'Comprar pó',
    checklist: [
      for (final (i, title) in const [
        'Passar o café',
        'Meditar',
        'Lavar a louça',
      ].indexed)
        ChecklistItem(title: title, done: i < done),
    ],
  );

  group('the model', () {
    test('reads a day’s list from the API, and the next item', () {
      final card = TimelineEvent.fromJson({
        'id': 'b',
        'kind': 'task',
        'title': 'Café da manhã',
        'section': 'dia',
        'startTime': now.toIso8601String(),
        'endTime': now.toIso8601String(),
        'durationMinutes': 30,
        'checklist': [
          {'title': 'Passar o café', 'done': true},
          {'title': 'Meditar', 'done': false},
        ],
      });

      expect(card.checklist, hasLength(2));
      expect(card.nextItem?.title, 'Meditar');
      expect(card.checklist.first.toJson(), {
        'title': 'Passar o café',
        'done': true,
      });
    });

    test('has no list, and no next item, when the API sends none', () {
      final card = TimelineEvent.fromJson({'id': 'x', 'title': 'Almoço'});
      expect(card.checklist, isEmpty);
      expect(card.nextItem, isNull);
    });

    test('a routine reads its list', () {
      final routine = Routine.fromJson({
        'id': 'r',
        'title': 'Café da manhã',
        'time': '07:00',
        'durationMinutes': 45,
        'days': 'daily',
        'checklist': ['Passar o café', 'Meditar'],
      });
      expect(routine.checklist, ['Passar o café', 'Meditar']);
    });
  });

  group('the card', () {
    Future<void> pump(
      WidgetTester tester,
      TimelineEvent card, {
      double? height,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 340,
                height: height,
                child: EventTile(card: card, preview: height != null),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('in Lista, draws the next item and how far the list got', (
      tester,
    ) async {
      await pump(tester, breakfast(done: 1));

      expect(find.text('Meditar'), findsOneWidget);
      expect(find.text('Passar o café'), findsNothing);
      expect(find.text('1 de 3'), findsOneWidget);
      // The list is where the notes would go.
      expect(find.textContaining('Comprar pó'), findsNothing);
    });

    testWidgets('says so once every item is ticked off', (tester) async {
      await pump(tester, breakfast(done: 3));
      expect(find.text(l10n.checklistAllDone), findsOneWidget);
      expect(find.text('3 de 3'), findsOneWidget);
    });

    testWidgets('on the calendar, draws every item when they fit', (
      tester,
    ) async {
      await pump(tester, breakfast(done: 1), height: 120);

      for (final title in ['Passar o café', 'Meditar', 'Lavar a louça']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('1 de 3'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on the calendar, falls back to the next item when short', (
      tester,
    ) async {
      await pump(tester, breakfast(done: 1), height: 74);

      expect(find.text('Meditar'), findsOneWidget);
      expect(find.text('Lavar a louça'), findsNothing);
      expect(tester.getSize(find.byType(EventTile)).height, 74);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Agora, draws the next item alone', (tester) async {
      await pump(
        tester,
        breakfast(section: TimelineSection.agora),
        height: 400,
      );
      expect(find.text('Passar o café'), findsOneWidget);
      expect(find.text('Meditar'), findsNothing);
    });
  });

  group('the page', () {
    testWidgets('ticks an item off with a tap', (tester) async {
      final timeline = _MockTimelineBloc();
      final shown = breakfast(done: 1);
      whenListen(
        timeline,
        const Stream<TimelineState>.empty(),
        initialState: TimelineState(
          status: TimelineStatus.success,
          cards: [shown],
          tasks: [shown],
        ),
      );

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          BlocProvider<TimelineBloc>.value(
            value: timeline,
            child: MaterialApp(
              theme: AppTheme.current,
              locale: const Locale('pt', 'BR'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const EventPage(id: 'b'),
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.text(l10n.eventChecklistLabel), findsOneWidget);
      await tester.tap(find.text('Lavar a louça'));
      verify(() => timeline.add(const ChecklistToggled('b', 2))).called(1);
    });
  });

  group('the bloc', () {
    late TimelineRepository repository;

    setUp(() {
      repository = _MockTimelineRepository();
      when(
        () => repository.edit(
          any(),
          any(),
          checklist: any(named: 'checklist'),
          days: any(named: 'days'),
        ),
      ).thenAnswer((_) => Completer<Timeline>().future);
    });

    blocTest<TimelineBloc, TimelineState>(
      'draws the tick at once and sends the whole list',
      build: () => TimelineBloc(repository: repository),
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: [breakfast()],
        tasks: [breakfast()],
      ),
      act: (bloc) => bloc.add(const ChecklistToggled('b', 0)),
      verify: (bloc) {
        expect(bloc.state.cards.single.checklist.first.done, isTrue);
        expect(bloc.state.tasks.single.nextItem?.title, 'Meditar');
        final sent =
            verify(
                  () => repository.edit(
                    CardKind.task,
                    'b',
                    checklist: captureAny(named: 'checklist'),
                    days: any(named: 'days'),
                  ),
                ).captured.single
                as List<ChecklistItem>;
        expect([for (final item in sent) item.done], [true, false, false]);
      },
    );
  });
}
