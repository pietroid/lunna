import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:timeline/timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Instants in UTC, so nothing here depends on the machine's zone.
  final start = DateTime.utc(2026, 10, 28, 13);
  final end = DateTime.utc(2026, 10, 28, 13, 30);

  TimelineEvent card({
    String id = 't-1',
    CardKind kind = CardKind.task,
    TimelineSection section = TimelineSection.agora,
    bool started = true,
    bool awaitingStart = false,
    DateTime? pausedAt,
    int remainingSeconds = 0,
    DateTime? overtimeFrom,
    DateTime? endTime,
    String? delivery,
  }) {
    return TimelineEvent(
      id: id,
      title: 'Escrever o relatório',
      kind: kind,
      section: section,
      startTime: start,
      endTime: endTime ?? end,
      durationMinutes: 30,
      started: started,
      awaitingStart: awaitingStart,
      pausedAt: pausedAt,
      remainingSeconds: remainingSeconds,
      overtimeFrom: overtimeFrom,
      artifactId: delivery == null ? null : 'a-1',
      artifactTitle: delivery,
    );
  }

  group('blockOf', () {
    test('is the begun task in Agora, counting down to its end', () {
      expect(blockOf([card(delivery: 'Site da Ana')]), {
        'id': 't-1',
        'kind': 'task',
        'title': 'Escrever o relatório',
        'delivery': 'Site da Ana',
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'work': 30 * 60,
        'pausedLeft': null,
      });
    });

    test('is a fixed block in Agora, which never waits to be begun', () {
      final block = blockOf([card(kind: CardKind.event, started: false)]);
      expect(block?['kind'], 'event');
    });

    test('is nothing for a task waiting to be begun, or anything later', () {
      expect(blockOf([card(started: false, awaitingStart: true)]), isNull);
      expect(blockOf([card(section: TimelineSection.dia)]), isNull);
      expect(blockOf([]), isNull);
    });

    test('keeps what was left when paused, whatever the clock does', () {
      final pausedAt = DateTime.utc(2026, 10, 28, 13, 10);
      final block = blockOf([
        card(
          pausedAt: pausedAt,
          remainingSeconds: 1200,
          // A paused block's end is dragged along with the clock.
          endTime: DateTime.utc(2026, 10, 28, 13, 47),
        ),
      ]);

      expect(block?['pausedLeft'], 1200);
      expect(
        block?['end'],
        DateTime.utc(2026, 10, 28, 13, 30).millisecondsSinceEpoch,
      );
    });

    test('counts up from the end it ran past, not the end being dragged', () {
      final block = blockOf([
        card(
          overtimeFrom: end,
          endTime: DateTime.utc(2026, 10, 28, 13, 41),
        ),
      ]);

      expect(block?['end'], end.millisecondsSinceEpoch);
    });
  });

  group('LiveActivity', () {
    const channel = MethodChannel(LiveActivity.channelName);
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'launchCard' ? 't-1' : null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    LiveActivity live({bool supported = true, bool enabled = true}) =>
        LiveActivity(
          apiBaseUrl: 'https://lunna.example/api',
          supported: supported,
          enabled: enabled,
        );

    test('sends the block once, and again only when it changes', () async {
      final activity = live();
      await activity.sync([card()]);
      await activity.sync([card()]);
      await activity.sync([card(pausedAt: start, remainingSeconds: 600)]);
      await activity.sync();

      expect(calls.map((it) => it.method), ['sync', 'sync', 'sync']);
      final first = calls.first.arguments as Map<Object?, Object?>;
      expect(first['apiBaseUrl'], 'https://lunna.example/api');
      expect((first['block']! as Map<Object?, Object?>)['id'], 't-1');
      expect((calls.last.arguments as Map<Object?, Object?>)['block'], isNull);
    });

    test('ends whatever is showing on its first sync, even with nothing', () {
      // An activity left from the last launch is ended by the first day
      // that has nothing running.
      return live().sync().then((_) => expect(calls, hasLength(1)));
    });

    test('sends again after a button changed the day', () async {
      final activity = live();
      final changes = <void>[];
      activity.changes.listen(changes.add);

      await activity.sync([card()]);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            LiveActivity.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('changed'),
            ),
            (_) {},
          );
      await activity.sync([card()]);

      expect(changes, hasLength(1));
      expect(calls.where((it) => it.method == 'sync'), hasLength(2));
    });

    test('switched off, ends the one showing and never starts one', () async {
      final activity = live(enabled: false);
      await activity.sync([card()]);
      await activity.sync([card(pausedAt: start, remainingSeconds: 600)]);

      expect(calls, hasLength(1));
      expect(
        (calls.single.arguments as Map<Object?, Object?>)['block'],
        isNull,
      );
      expect(kLiveActivity, isFalse);
    });

    test('hands over the card a tap launched the app on', () async {
      expect(await live().launchCard(), 't-1');
    });

    test('does nothing where there is no activity (web, Android)', () async {
      final activity = live(supported: false);
      await activity.sync([card()]);
      expect(await activity.launchCard(), isNull);
      expect(calls, isEmpty);
    });
  });
}
