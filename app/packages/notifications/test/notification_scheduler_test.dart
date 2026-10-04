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

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {}

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
  Future<void> cancel(int id) async {
    cancelled.add(id);
    queued.remove(id);
  }
}

final _now = DateTime.utc(2026, 9, 21, 15);

PlannedNotification _item(String id, {int minutes = 60, String? slug}) {
  return PlannedNotification(
    id: id,
    kind: NotificationKind.starting,
    fireAt: _now.add(Duration(minutes: minutes)),
    title: 'Revisão de código',
    body: 'Começa agora, até 15:00',
    timeSensitive: true,
    threadSlug: slug,
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

    test('carries the conversation to open on tap', () async {
      planIs([_item('a', slug: 'revisao-de-codigo')]);

      await scheduler.sync();

      final payload = queue.queued[queueIdOf('a')]!.payload;
      expect(tapOf(payload).threadSlug, 'revisao-de-codigo');
    });

    test('carries the block a start question is about', () async {
      planIs([
        PlannedNotification(
          id: 'ask',
          kind: NotificationKind.confirmStart,
          fireAt: _now.add(const Duration(minutes: 30)),
          title: 'Escrever',
          body: 'Está na hora. Começamos?',
          eventId: 'evt-1',
        ),
      ]);

      await scheduler.sync();

      final tap = tapOf(queue.queued[queueIdOf('ask')]!.payload);
      expect(tap.confirmStart, isTrue);
      expect(tap.eventId, 'evt-1');
      expect(tap.title, 'Escrever');
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
            'id': 'starting:evt-1:1758470700:ab12cd34',
            'kind': 'starting',
            'fireAt': '2026-09-21T13:55:00-03:00',
            'title': 'Revisão de código',
            'body': 'Começa agora, até 15:00',
            'timeSensitive': true,
            'threadSlug': 'revisao-de-codigo',
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
      expect(plan.items.single.threadSlug, 'revisao-de-codigo');
    });
  });
}
