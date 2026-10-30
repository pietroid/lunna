import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRepository extends Mock implements NotificationsRepository {}

/// The device's queue, standing in: it holds whatever it was given.
class _FakeQueue implements NotificationQueue {
  bool permitted = true;
  bool grants = true;
  int requests = 0;
  final Map<int, QueuedNotification> queued = {};
  final List<int> cancelled = [];
  final List<DeliveredNotification> shown = [];

  void Function(String? payload)? onTap;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    permitted = grants;
    return grants;
  }

  @override
  Future<Set<int>> pendingIds() async => queued.keys.toSet();

  @override
  Future<void> schedule(QueuedNotification notification) async {
    queued[notification.id] = notification;
  }

  @override
  Future<List<DeliveredNotification>> delivered() async => [...shown];

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    queued.remove(id);
    shown.removeWhere((it) => it.id == id);
  }
}

final _now = DateTime.utc(2026, 9, 21, 15);

PlannedNotification _item(String id, {int minutes = 60, String? eventId}) {
  return PlannedNotification(
    id: id,
    kind: NotificationKind.askStart,
    fireAt: _now.add(Duration(minutes: minutes)),
    title: 'Revisão de código',
    body: 'Começando agora, certo?',
    timeSensitive: true,
    eventId: eventId,
  );
}

void main() {
  late _MockRepository repository;
  late _FakeQueue queue;
  late NotificationScheduler scheduler;

  void planIs(List<PlannedNotification> items) {
    when(() => repository.fetchPlan()).thenAnswer(
      (_) async =>
          NotificationPlan(timeZone: 'America/Sao_Paulo', items: items),
    );
  }

  setUpAll(() {
    registerFallbackValue(const NotificationAnswer(path: '/'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _MockRepository();
    queue = _FakeQueue();
    scheduler = NotificationScheduler(
      repository: repository,
      queue: queue,
      now: () => _now,
      supported: true,
    );
  });

  group('sync', () {
    test('queues every planned reminder, on the calendar zone', () async {
      planIs([_item('a'), _item('b', minutes: 90)]);

      await scheduler.sync();

      expect(queue.queued, hasLength(2));
      final first = queue.queued[queueIdOf('a')]!;
      expect(first.fireAt.location.name, 'America/Sao_Paulo');
      expect(first.fireAt.hour, 13);
      expect(first.timeSensitive, isTrue);
    });

    test("names the brand's agent on the suggestion, the rest as "
        'written', () async {
      final suggestion = PlannedNotification(
        id: 'suggestion',
        kind: NotificationKind.suggestion,
        fireAt: _now.add(const Duration(hours: 3)),
        title: 'Uma sugestão para o seu mês',
        body: 'Tenho uma ideia para o próximo passo. Vem ver?',
      );
      planIs([_item('a'), suggestion]);

      for (final (brand, title) in [
        ('lunna', 'A Lunna te mandou uma mensagem'),
        ('focus', 'O Focus te mandou uma mensagem'),
      ]) {
        queue.queued.clear();
        await NotificationScheduler(
          repository: repository,
          queue: queue,
          now: () => _now,
          supported: true,
          brand: brand,
        ).sync();

        expect(queue.queued[queueIdOf('suggestion')]!.title, title);
        expect(
          queue.queued[queueIdOf('suggestion')]!.body,
          'Tenho uma ideia para o próximo passo. Vem ver?',
        );
        expect(queue.queued[queueIdOf('a')]!.title, 'Revisão de código');
      }
    });

    test('leaves what is already queued alone', () async {
      planIs([_item('a')]);
      await scheduler.sync();
      final before = queue.queued[queueIdOf('a')];

      await scheduler.sync();

      expect(identical(queue.queued[queueIdOf('a')], before), isTrue);
      expect(queue.cancelled, isEmpty);
    });

    test('takes off what the plan dropped', () async {
      planIs([_item('a'), _item('b')]);
      await scheduler.sync();

      planIs([_item('b')]);
      await scheduler.sync();

      expect(queue.cancelled, [queueIdOf('a')]);
      expect(queue.queued.keys, [queueIdOf('b')]);
    });

    test('keeps the last good queue when the plan cannot be read', () async {
      planIs([_item('a')]);
      await scheduler.sync();

      when(() => repository.fetchPlan()).thenThrow(Exception('offline'));
      await scheduler.sync();

      expect(queue.queued.keys, [queueIdOf('a')]);
    });

    test('does nothing without permission', () async {
      queue.permitted = false;
      planIs([_item('a')]);

      await scheduler.sync();

      expect(queue.queued, isEmpty);
      verifyNever(() => repository.fetchPlan());
    });

    test('folds calls that overlap into one rerun', () async {
      planIs([_item('a')]);

      await Future.wait([scheduler.sync(), scheduler.sync(), scheduler.sync()]);

      verify(() => repository.fetchPlan()).called(2);
      expect(queue.queued, hasLength(1));
    });

    test('carries the block to open on tap', () async {
      planIs([_item('a', eventId: 'evt-1')]);

      await scheduler.sync();

      final payload = queue.queued[queueIdOf('a')]!.payload;
      expect(tapOf(payload).eventId, 'evt-1');
    });

    test('carries the block a start question is about', () async {
      planIs([
        PlannedNotification(
          id: 'ask',
          kind: NotificationKind.askStart,
          fireAt: _now.add(const Duration(minutes: 30)),
          title: 'Escrever',
          body: 'Começando agora, certo?',
          eventId: 'evt-1',
          card: NotificationCard.task,
          edge: NotificationEdge.start,
        ),
      ]);

      await scheduler.sync();

      final queued = queue.queued[queueIdOf('ask')]!;
      final tap = tapOf(queued.payload);
      expect(tap.asks, isTrue);
      expect(tap.kind, NotificationKind.askStart);
      expect(tap.card, NotificationCard.task);
      expect(tap.eventId, 'evt-1');
      expect(tap.title, 'Escrever');
      expect(tap.edge, NotificationEdge.start);
    });

    test('files the reminders of one card under its thread', () async {
      planIs([
        _item('a', eventId: 'evt-1'),
        PlannedNotification(
          id: 'morning',
          kind: NotificationKind.morning,
          fireAt: _now.add(const Duration(hours: 2)),
          title: 'Bom dia',
          body: 'Bora?',
        ),
      ]);

      await scheduler.sync();

      expect(queue.queued[queueIdOf('a')]!.thread, 'evt-1');
      expect(queue.queued[queueIdOf('morning')]!.thread, isNull);
    });

    test(
      'lets each reminder go, on Android, when the next one is due',
      () async {
        planIs([_item('a'), _item('b', minutes: 70), _item('c', minutes: 70)]);

        await scheduler.sync();

        expect(
          queue.queued[queueIdOf('a')]!.timeout,
          const Duration(minutes: 10),
        );
        expect(queue.queued[queueIdOf('b')]!.timeout, isNull);
        expect(queue.queued[queueIdOf('c')]!.timeout, isNull);
      },
    );

    test('clears the reminders shown but the one that fired last', () async {
      DeliveredNotification shown(String id, int minutesAgo) =>
          DeliveredNotification(
            id: queueIdOf(id),
            payload: payloadOf(_item(id, minutes: -minutesAgo)),
          );
      queue.shown.addAll([
        shown('start', 20),
        shown('end', 10),
        shown('end+10', 0),
        // From a version whose payload had no hour: always older.
        const DeliveredNotification(id: 7, payload: '{"id":"old"}'),
      ]);
      planIs([]);

      await scheduler.sync();

      expect(queue.shown.map((it) => it.id), [queueIdOf('end+10')]);
    });

    test('files the morning and evening reminders apart', () async {
      planIs([
        PlannedNotification(
          id: 'morning',
          kind: NotificationKind.morning,
          fireAt: _now.add(const Duration(hours: 2)),
          title: 'Bom dia',
          body: 'Bora?',
        ),
      ]);

      await scheduler.sync();

      expect(queue.queued.values.single.daily, isTrue);
    });
  });

  group('answer', () {
    test('maps each answer on each edge of each card to its route', () {
      String? route(
        NotificationCard card,
        NotificationEdge edge,
        NotificationAction action,
      ) {
        final answer = NotificationAnswer.of(
          card: card,
          edge: edge,
          id: 'id 1',
          action: action,
        );
        return answer == null ? null : '${answer.path} ${answer.data ?? ''}';
      }

      const task = NotificationCard.task;
      const event = NotificationCard.event;
      const start = NotificationEdge.start;
      const end = NotificationEdge.end;
      const confirm = NotificationAction.confirm;
      const later = NotificationAction.later;
      const talk = NotificationAction.talk;

      expect(route(task, start, confirm), '/tasks/id%201/start ');
      expect(route(task, start, later), '/tasks/id%201/snooze {minutes: 10}');
      expect(route(task, end, confirm), '/tasks/id%201/done ');
      expect(route(task, end, later), '/tasks/id%201/extend {minutes: 10}');
      expect(route(event, start, confirm), '/events/id%201/start ');
      expect(route(event, start, later), '/events/id%201/delay {minutes: 10}');
      expect(route(event, end, confirm), '/events/id%201/done ');
      expect(route(event, end, later), '/events/id%201/extend {minutes: 10}');
      expect(route(task, start, talk), isNull);
      expect(route(event, end, talk), isNull);
    });

    test('posts the answer, clears every reminder shown, then syncs, which '
        'takes off the re-asks', () async {
      when(() => repository.answer(any())).thenAnswer((_) async {});
      planIs([_item('ask'), _item('ask+10', minutes: 70)]);
      await scheduler.sync();
      queue.shown.add(DeliveredNotification(id: queueIdOf('before')));
      planIs([]);

      await scheduler.answer(
        const NotificationAnswer(path: '/events/id%201/start'),
      );

      verify(
        () => repository.answer(
          const NotificationAnswer(path: '/events/id%201/start'),
        ),
      ).called(1);
      expect(queue.queued, isEmpty);
      expect(queue.shown, isEmpty);
    });

    test('hands a tap to the taps', () async {
      await scheduler.initialize();

      final tapped = scheduler.taps.first;
      queue.onTap!(payloadOf(_item('a', eventId: 'e')));
      expect((await tapped).eventId, 'e');
    });
  });

  group('permission', () {
    test('is asked once, whatever the answer', () async {
      queue.grants = false;

      expect(await scheduler.shouldAskPermission(), isTrue);
      expect(await scheduler.requestPermission(), isFalse);
      expect(await scheduler.shouldAskPermission(), isFalse);
    });

    test('is not asked again once turned down in the app', () async {
      await scheduler.declinePermission();

      expect(await scheduler.shouldAskPermission(), isFalse);
      expect(queue.requests, 0);
    });

    test('syncs as soon as it is granted', () async {
      queue.permitted = false;
      planIs([_item('a')]);

      await scheduler.requestPermission();

      expect(queue.queued, hasLength(1));
    });

    test('is never asked where reminders are not supported', () async {
      final web = NotificationScheduler(
        repository: repository,
        queue: queue,
        supported: false,
      );

      expect(await web.shouldAskPermission(), isFalse);
      expect(await web.requestPermission(), isFalse);
      expect(queue.requests, 0);
    });
  });

  group('reconcile', () {
    test('skips anything already past', () {
      final diff = reconcile([_item('past', minutes: -5)], {}, _now);

      expect(diff.schedule, isEmpty);
    });

    test('keeps only the soonest sixty', () {
      final items = [
        for (var i = 70; i > 0; i--) _item('item-$i', minutes: i),
      ];

      final diff = reconcile(items, {}, _now);

      expect(diff.schedule, hasLength(NotificationScheduler.maxQueued));
      expect(diff.schedule.first.id, 'item-1');
      expect(diff.schedule.last.id, 'item-60');
    });

    test('cancels a queued reminder that fell outside the sixty', () {
      final items = [
        for (var i = 1; i <= 61; i++) _item('item-$i', minutes: i),
      ];
      final farthest = queueIdOf('item-61');

      final diff = reconcile(items, {farthest}, _now);

      expect(diff.cancel, {farthest});
    });
  });

  group('ids', () {
    test('are the same on every launch', () {
      expect(queueIdOf('starting:evt-1:1758470700:ab12cd34'), 396245587);
    });

    test('are positive 32-bit integers', () {
      for (var i = 0; i < 500; i++) {
        final id = queueIdOf('item-$i');
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });
  });

  group('the plan on the wire', () {
    test('reads the server payload and drops what it does not know', () {
      final plan = NotificationPlan.fromJson(const {
        'timeZone': 'America/Sao_Paulo',
        'items': [
          {
            'id': 'askStart:evt-1:1758470700:ab12cd34',
            'kind': 'askStart',
            'fireAt': '2026-09-21T13:55:00-03:00',
            'title': 'Revisão de código',
            'body': 'Começando agora, certo?',
            'timeSensitive': true,
            'eventId': 'evt-1',
            'card': 'event',
            'edge': 'start',
          },
          {
            'id': 'old',
            'kind': 'almostFinishing',
            'fireAt': '2026-09-21T13:55:00-03:00',
            'title': 't',
            'body': 'b',
          },
          {
            'id': 'x',
            'kind': 'somethingNew',
            'fireAt': '2026-09-21T13:55:00-03:00',
            'title': 't',
            'body': 'b',
          },
        ],
      });

      expect(plan.items, hasLength(1));
      expect(plan.items.single.fireAt, DateTime.utc(2026, 9, 21, 16, 55));
      expect(plan.items.single.eventId, 'evt-1');
      expect(plan.items.single.card, NotificationCard.event);
      expect(plan.items.single.edge, NotificationEdge.start);
      expect(plan.items.single.asks, isTrue);
    });
  });
}
