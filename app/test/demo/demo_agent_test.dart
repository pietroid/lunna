import 'package:agent/agent.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';

void main() {
  /// Thursday 22 October 2026, ten in the morning, wherever this runs.
  final now = DateTime(2026, 10, 22, 10);
  final tomorrow = DateTime(2026, 10, 23);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  void testAt(String description, Future<void> Function() body) {
    test(description, () => withClock(Clock.fixed(now), body));
  }

  ({
    DemoTimelineRepository timeline,
    DemoArtifactsRepository artifacts,
    DemoAgentRepository agent,
  })
  demo() {
    final timeline = DemoTimelineRepository(l10n);
    final artifacts = DemoArtifactsRepository(l10n);
    return (
      timeline: timeline,
      artifacts: artifacts,
      agent: DemoAgentRepository(
        l10n,
        timeline: timeline,
        artifacts: artifacts,
      ),
    );
  }

  Future<String> ask(DemoAgentRepository agent, String text) async {
    final (:conversationId, :reply) = await agent.turn([UserEntry(text)]);
    return reply.plan!.id;
  }

  group('DemoAgentRepository', () {
    testAt('applies the study plan at the hours it shows', () async {
      final (:timeline, :artifacts, :agent) = demo();
      final plan = await ask(agent, l10n.demoAskStudy);

      final day = await agent.apply(plan);

      final study = day.tasks.singleWhere((t) => t.title == l10n.demoStudy);
      expect(
        study.startTime,
        tomorrow.add(const Duration(hours: 9, minutes: 35)),
      );
      final photos = day.tasks.singleWhere((t) => t.id == 'fotos');
      expect(photos.startTime, tomorrow.add(const Duration(hours: 14)));
      expect(day.backlog, isEmpty);
    });

    testAt('undo puts the day back as it was', () async {
      final (:timeline, :artifacts, :agent) = demo();
      final before = await timeline.fetch();
      final plan = await ask(agent, l10n.demoAskStudy);
      await agent.apply(plan);

      final after = await agent.undo(plan);

      expect(after.tasks, before.tasks);
      expect(after.backlog, before.backlog);
      expect(after.cards, before.cards);
    });

    testAt(
      'the delivery plan writes a delivery, and undo takes it back',
      () async {
        final (:timeline, :artifacts, :agent) = demo();
        final before = artifacts.data;
        final plan = await ask(agent, l10n.demoAskDelivery);

        await agent.apply(plan);
        final made = artifacts.data.queue.last;
        expect(made.title, l10n.demoDeliveryCarla);
        expect(made.type?.id, 'mapa');
        expect(made.deadline, DateTime(2026, 10, 23, 18));

        await agent.undo(plan);
        expect(artifacts.data, before);
      },
    );

    testAt('undoing a plan never applied is refused', () async {
      final (:timeline, :artifacts, :agent) = demo();

      await expectLater(agent.undo('demo-study'), throwsA(isA<AgentFailure>()));
    });
  });

  group('DemoArtifactsRepository', () {
    testAt('keeps what is written, moved, delivered and removed', () async {
      final artifacts = DemoArtifactsRepository(l10n);

      var data = await artifacts.create(title: 'Mapa da Ana', typeId: 'mapa');
      expect(data.queue.last.title, 'Mapa da Ana');
      expect(data.queue.last.minutes, 180);

      final id = data.queue.last.id;
      data = await artifacts.move(id, 0);
      expect(data.queue.first.id, id);

      data = await artifacts.update(id, done: true);
      expect(data.done.single.id, id);
      expect(data.done.single.doneAt, now);

      data = await artifacts.delete(id);
      expect(data.artifacts.where((it) => it.id == id), isEmpty);
    });
  });

  group('DemoClock', () {
    test('reads ten in the morning while pinned, and the clock after', () {
      final night = DateTime(2026, 10, 22, 0, 31);
      withClock(DemoClock.around(Clock.fixed(night)), () {
        DemoClock.pin();
        DemoClock.pin();
        expect(clock.now(), DateTime(2026, 10, 22, DemoClock.hour));
        DemoClock.unpin();
        expect(clock.now(), DateTime(2026, 10, 22, DemoClock.hour));
        DemoClock.unpin();
        expect(clock.now(), night);
        DemoClock.unpin();
        expect(clock.now(), night);
      });
    });
  });
}
