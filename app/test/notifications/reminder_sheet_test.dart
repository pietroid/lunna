import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:lunna/notifications/view/reminder_sheet.dart';
import 'package:lunna/notifications/view/reminders_listener.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

class _MockScheduler extends Mock implements NotificationScheduler {}

class _MockTimeline extends Mock implements TimelineRepository {}

final AppLocalizations l10n = lookupAppLocalizations(const Locale('pt'));

/// Ten in the morning, wherever this runs.
final now = DateTime(2026, 10, 29, 10);

/// Café, begun at nine for an hour; [over] minutes past its end.
TimelineEvent coffee({
  int over = 0,
  bool started = true,
  bool awaiting = false,
  int endsIn = 0,
  bool fixed = false,
}) => TimelineEvent(
  id: 'c',
  title: 'Café',
  section: TimelineSection.agora,
  kind: fixed ? CardKind.event : CardKind.task,
  fixed: fixed,
  started: started,
  awaitingStart: awaiting,
  startTime: now.subtract(const Duration(hours: 1)),
  endTime: now.add(Duration(minutes: endsIn)),
  durationMinutes: 60 + endsIn,
  overtimeMinutes: over,
  overtimeFrom: over > 0 ? now.subtract(Duration(minutes: over)) : null,
);

NotificationTap tapOn(NotificationCard card, NotificationEdge edge) =>
    NotificationTap(
      eventId: 'c',
      title: 'Café',
      kind: edge == NotificationEdge.start
          ? NotificationKind.askStart
          : NotificationKind.askEnd,
      card: card,
      edge: edge,
    );

TimelineState dayOf(List<TimelineEvent> cards) => TimelineState(
  status: TimelineStatus.success,
  tasks: cards.where((card) => card.isTask).toList(),
  cards: cards,
);

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.current,
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  group('ReminderSheet', () {
    Future<NotificationAction?> answer(
      WidgetTester tester,
      ReminderAsk ask, {
      required String tap,
      List<String> expectAll = const [],
    }) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (it) {
              context = it;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final result = ReminderSheet.show(context, ask);
      await tester.pumpAndSettle();

      for (final text in expectAll) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    ReminderAsk ask(
      NotificationCard card,
      NotificationEdge edge, {
      int late = 0,
    }) => ReminderAsk(
      title: 'Café',
      card: card,
      edge: edge,
      hours: '09:00–10:00',
      lateMinutes: late,
    );

    testWidgets("a task's start: Esperar 10 min, Começar, the agent", (
      tester,
    ) async {
      final action = await answer(
        tester,
        ask(NotificationCard.task, NotificationEdge.start),
        tap: 'Começar',
        expectAll: [
          '09:00–10:00',
          'Café',
          'Começando agora, certo?',
          'Esperar 10 min',
          l10n.notificationActionTalk(AppBrand.id),
        ],
      );

      expect(action, NotificationAction.confirm);
    });

    testWidgets("a fixed block's start puts it off: Adiar 10 min", (
      tester,
    ) async {
      final action = await answer(
        tester,
        ask(NotificationCard.event, NotificationEdge.start),
        tap: 'Adiar 10 min',
        expectAll: ['Confirmar'],
      );

      expect(action, NotificationAction.later);
    });

    testWidgets('an end: Mais 10 min on the left, Terminei on the right', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (it) {
              context = it;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      unawaited(
        ReminderSheet.show(
          context,
          ask(NotificationCard.event, NotificationEdge.end),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terminando agora, certo?'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Mais 10 min')).dx,
        lessThan(tester.getCenter(find.text('Terminei')).dx),
      );
    });

    testWidgets('a late end says how late, and talking is an answer too', (
      tester,
    ) async {
      final action = await answer(
        tester,
        ask(NotificationCard.task, NotificationEdge.end, late: 12),
        tap: l10n.notificationActionTalk(AppBrand.id),
        expectAll: ['Atraso no término · 12 minutos', 'Terminei'],
      );

      expect(find.text('Terminando agora, certo?'), findsNothing);
      expect(action, NotificationAction.talk);
    });
  });

  group('ReminderAsk.of', () {
    ReminderAsk? of(NotificationTap tap, List<TimelineEvent> cards) =>
        ReminderAsk.of(tap, dayOf(cards), now, l10n);

    const task = NotificationCard.task;
    const event = NotificationCard.event;
    const start = NotificationEdge.start;
    const end = NotificationEdge.end;

    test('asks a late end with the minutes now and the planned hours', () {
      final ask = of(tapOn(task, end), [coffee(over: 12)])!;

      expect(ask.title, 'Café');
      expect(ask.lateMinutes, 12);
      expect(ask.hours, '09:00–09:48');
    });

    test('asks an end that has come', () {
      expect(of(tapOn(task, end), [coffee()]), isNotNull);
    });

    test('asks nothing of an end given more time, or of a card gone', () {
      expect(of(tapOn(task, end), [coffee(endsIn: 10)]), isNull);
      expect(of(tapOn(task, end), []), isNull);
    });

    test("asks a task's start only while it waits to be begun", () {
      final waiting = coffee(started: false, awaiting: true);
      expect(of(tapOn(task, start), [waiting]), isNotNull);
      expect(of(tapOn(task, start), [coffee()]), isNull);
    });

    test("asks a fixed block's start while it runs, not once put off", () {
      expect(
        of(tapOn(event, start), [coffee(fixed: true, endsIn: 30)]),
        isNotNull,
      );
      final later = TimelineEvent(
        id: 'c',
        title: 'Café',
        section: TimelineSection.dia,
        kind: CardKind.event,
        fixed: true,
        startTime: now.add(const Duration(minutes: 10)),
        endTime: now.add(const Duration(minutes: 40)),
        durationMinutes: 30,
      );
      expect(of(tapOn(event, start), [later]), isNull);
    });

    test('asks nothing for a reminder that asked nothing', () {
      const headsUp = NotificationTap(
        eventId: 'c',
        kind: NotificationKind.headsUp,
        card: NotificationCard.event,
        edge: NotificationEdge.start,
      );
      expect(of(headsUp, [coffee(fixed: true, endsIn: 30)]), isNull);
    });
  });

  group('RemindersListener', () {
    late _MockScheduler scheduler;
    late _MockTimeline repository;
    late StreamController<NotificationTap> taps;

    setUpAll(() {
      registerFallbackValue(const NotificationAnswer(path: '/'));
    });

    setUp(() {
      scheduler = _MockScheduler();
      repository = _MockTimeline();
      taps = StreamController<NotificationTap>.broadcast();
      when(() => scheduler.taps).thenAnswer((_) => taps.stream);
      when(() => scheduler.launchTap()).thenAnswer((_) async => null);
      when(() => scheduler.sync()).thenAnswer((_) async {});
      when(
        () => scheduler.shouldAskPermission(),
      ).thenAnswer((_) async => false);
      when(() => scheduler.answer(any())).thenAnswer((_) async {});
    });

    tearDown(() => taps.close());

    Future<void> pump(WidgetTester tester, List<TimelineEvent> cards) async {
      when(
        () => repository.fetch(days: any(named: 'days')),
      ).thenAnswer((_) async => Timeline(tasks: cards, cards: cards));

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<NotificationScheduler>.value(value: scheduler),
            RepositoryProvider<LiveActivity>.value(
              value: LiveActivity(apiBaseUrl: '', supported: false),
            ),
          ],
          child: BlocProvider(
            create: (_) => TimelineBloc(repository: repository),
            child: app(const RemindersListener(child: SizedBox.expand())),
          ),
        ),
      );
    }

    testWidgets('a tap opens the question, and its answer posts the route', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, [coffee(over: 12)]);

        taps.add(tapOn(NotificationCard.task, NotificationEdge.end));
        await tester.pumpAndSettle();

        expect(find.text('Atraso no término · 12 minutos'), findsOneWidget);
        await tester.tap(find.text('Terminei'));
        await tester.pumpAndSettle();
      });

      verify(
        () => scheduler.answer(const NotificationAnswer(path: '/tasks/c/done')),
      ).called(1);
    });

    testWidgets('a tap on an edge already answered just opens Tempo', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, [coffee(endsIn: 10)]);

        taps.add(tapOn(NotificationCard.task, NotificationEdge.end));
        await tester.pumpAndSettle();
      });

      expect(find.byType(ReminderSheet), findsNothing);
      verifyNever(() => scheduler.answer(any()));
    });
  });
}
