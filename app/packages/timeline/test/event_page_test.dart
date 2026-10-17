import 'dart:async';

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

  /// Ten in the morning, wherever this runs: the page reads [clock].
  final now = DateTime(2026, 6, 10, 10);

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  TimelineEvent card(String id, String kind, {String notes = 'Pão'}) =>
      TimelineEvent.fromJson({
        'id': id,
        'kind': kind,
        'title': 'Mercado',
        'section': 'dia',
        'notes': notes,
        'startTime': now.add(const Duration(hours: 1)).toIso8601String(),
        'endTime': now.add(const Duration(hours: 2)).toIso8601String(),
        'durationMinutes': 60,
        'workMinutes': 60,
      });

  late _MockTimelineBloc timeline;
  late StreamController<TimelineState> states;
  // What the dock was handed: the notes, and the task they are a task's
  // notes of.
  LiveTextController? notes;
  String? taskId;

  Future<void> pump(WidgetTester tester, TimelineEvent shown) async {
    timeline = _MockTimelineBloc();
    states = StreamController<TimelineState>();
    addTearDown(states.close);
    whenListen(
      timeline,
      states.stream,
      initialState: TimelineState(
        status: TimelineStatus.success,
        cards: [shown],
        tasks: [if (shown.isTask) shown],
      ),
    );

    await tester.pumpWidget(
      BlocProvider<TimelineBloc>.value(
        value: timeline,
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventPage(
            id: shown.id,
            dock: (context, given, id) {
              notes = given;
              taskId = id;
              return const SizedBox(key: Key('dock'), height: 56);
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testAt('floats the dock over a task’s notes, naming the task', (
    tester,
  ) async {
    await pump(tester, card('t1', 'task'));

    expect(find.byKey(const Key('dock')), findsOneWidget);
    expect(taskId, 't1');
    expect(notes!.text, 'Pão');
  });

  testAt('a fixed block’s dock names no task', (tester) async {
    await pump(tester, card('e1', 'event'));

    expect(find.byKey(const Key('dock')), findsOneWidget);
    expect(taskId, isNull);
  });

  testAt('saves what is dictated, and is not overwritten by its echo', (
    tester,
  ) async {
    await pump(tester, card('t1', 'task'));

    notes!.write(
      'Pão\n\nLevar sacolas',
      live: const TextRange(start: 5, end: 18),
    );
    await tester.pump(const Duration(seconds: 1));
    verify(
      () =>
          timeline.add(const EventEdited('t1', notes: 'Pão\n\nLevar sacolas')),
    ).called(1);

    // The server's copy of what was just saved comes back, then the
    // recognizer revises its last words: neither undoes the other.
    final echo = card('t1', 'task', notes: 'Pão\n\nLevar sacolas');
    states.add(
      TimelineState(
        status: TimelineStatus.success,
        cards: [echo],
        tasks: [echo],
      ),
    );
    await tester.pump();
    expect(notes!.text, 'Pão\n\nLevar sacolas');
    notes!.write(
      'Pão\n\nLevar sacolas e o carrinho',
      live: const TextRange(start: 5, end: 31),
    );
    await tester.pump();
    expect(notes!.text, 'Pão\n\nLevar sacolas e o carrinho');

    notes!.settle();
    await tester.pump(const Duration(seconds: 1));
    verify(
      () => timeline.add(
        const EventEdited('t1', notes: 'Pão\n\nLevar sacolas e o carrinho'),
      ),
    ).called(1);
  });
}
