import 'package:agent/agent.dart';
import 'package:api_client/api_client.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/data/demo_repositories.dart';
import 'package:timeline/timeline.dart';

/// {@template demo_agent_repository}
/// The agent, answering from a script.
///
/// Each of the landing page's example asks has its answer written down here,
/// and anything else typed gets the first one's: the demo shows what an
/// answer looks like, not what the model would make of every sentence. A
/// plan applied lands on the [timeline] and the [artifacts] the phone is
/// drawing, and undoing it puts back the day it found.
/// {@endtemplate}
class DemoAgentRepository implements AgentRepository {
  /// {@macro demo_agent_repository}
  DemoAgentRepository(
    this._l10n, {
    required this.timeline,
    required this.artifacts,
    this.offer,
  });

  final AppLocalizations _l10n;

  /// The day the demo draws, where an applied plan writes.
  final DemoTimelineRepository timeline;

  /// The deliveries the demo draws, where a plan's new delivery goes.
  final DemoArtifactsRepository artifacts;

  /// What Tempo is offered without asking; none on the landing page.
  final AgentSuggestion? offer;

  final _plans = <String, AgentPlan>{};

  /// What each applied plan found, to put back on undo.
  final _before = <String, (DemoDay, ArtifactsData)>{};

  /// What the landing page offers to ask, in order. The first is the one the
  /// phone opens on.
  static List<String> asks(AppLocalizations l10n) => [
    l10n.demoAskStudy,
    l10n.demoAskDelivery,
  ];

  @override
  ApiClient get apiClient => throw UnsupportedError('the demo has no server');

  @override
  Future<({String conversationId, AgentReply reply})> turn(
    List<AgentEntry> history, {
    String? conversationId,
    DateTime? day,
    AgentSubject? about,
  }) async {
    // Long enough for the thinking dots to be seen.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final said = switch (history.lastOrNull) {
      UserEntry(:final text) => text,
      _ => '',
    };
    final reply = demoReply(_l10n, said);
    if (reply.plan case final plan?) _plans[plan.id] = plan;

    return (conversationId: 'demo', reply: reply);
  }

  @override
  Future<Timeline> apply(
    String planId, {
    int days = TimelineRepository.defaultDays,
  }) async {
    final plan = _plans[planId];
    if (plan == null) throw const AgentFailure();
    _before[planId] = (timeline.snapshot(), artifacts.data);
    for (final change in plan.changes) {
      switch (change.kind) {
        case PlanChangeKind.addTask:
          await timeline.createTask(
            title: change.title,
            minutes: change.minutes,
            placement: Placement.at(change.at!),
            days: days,
          );
        case PlanChangeKind.moveTask when change.id != null:
          await timeline.moveTask(change.id!, 0, after: change.at, days: days);
        case PlanChangeKind.addArtifact:
          await artifacts.create(
            title: change.title,
            typeId: 'mapa',
            deadline: change.deadline,
          );
        // The scripted plans make nothing else.
        case _:
          break;
      }
    }
    return timeline.fetch(days: days);
  }

  @override
  Future<Timeline> undo(
    String planId, {
    int days = TimelineRepository.defaultDays,
  }) async {
    final (day, deliveries) =
        _before.remove(planId) ?? (throw const AgentFailure());
    timeline.restore(day);
    artifacts.data = deliveries;
    return timeline.fetch(days: days);
  }

  @override
  Future<List<PastConversation>> conversations({
    DateTime? before,
    int limit = 10,
  }) async => const [];

  @override
  Future<AgentSuggestion?> suggestion() async {
    final offer = this.offer;
    for (final plan in [?offer?.action?.plan, ...?offer?.opening?.plans]) {
      _plans[plan.id] = plan;
    }
    return offer;
  }
}

/// What the agent answers to [said] in the demo: the delivery for its ask,
/// the study plan for anything else.
AgentReply demoReply(AppLocalizations l10n, String said) =>
    said == l10n.demoAskDelivery ? _delivery(l10n) : _study(l10n);

/// Two hours of study tomorrow morning, after the dentist, and the photos
/// taken out of the backlog in the afternoon.
AgentReply _study(AppLocalizations l10n) {
  final tomorrow = _tomorrow();
  final study = tomorrow.add(const Duration(hours: 9, minutes: 35));

  return AgentReply(
    text: l10n.demoReplyStudy,
    steps: [l10n.demoStepLooked, l10n.demoStepFree],
    plan: AgentPlan(
      id: 'demo-study',
      changes: [
        PlanChange(
          kind: PlanChangeKind.addTask,
          title: l10n.demoStudy,
          minutes: 120,
          at: study,
        ),
        PlanChange(
          kind: PlanChangeKind.moveTask,
          id: 'fotos',
          title: l10n.demoBacklog,
          minutes: 60,
          at: tomorrow.add(const Duration(hours: 14)),
        ),
      ],
    ),
  );
}

/// A new delivery, owed on Friday.
AgentReply _delivery(AppLocalizations l10n) {
  final now = clock.now();
  final friday = DateTime(
    now.year,
    now.month,
    now.day + (DateTime.friday - now.weekday) % 7,
    18,
  );

  return AgentReply(
    text: l10n.demoReplyDelivery,
    steps: [l10n.demoStepCatalogue],
    plan: AgentPlan(
      id: 'demo-delivery',
      changes: [
        PlanChange(
          kind: PlanChangeKind.addArtifact,
          title: l10n.demoDeliveryCarla,
          minutes: 180,
          deadline: friday,
        ),
      ],
    ),
  );
}

DateTime _tomorrow() {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day + 1);
}

/// {@template demo_voice_recognizer}
/// No microphone in the demo: the bar says so, and typing still works.
/// {@endtemplate}
class DemoVoiceRecognizer implements VoiceRecognizer {
  /// {@macro demo_voice_recognizer}
  const DemoVoiceRecognizer();

  @override
  Future<VoiceAvailability> prepare() async => VoiceAvailability.unavailable;

  @override
  Future<void> listen({
    required VoiceWords onWords,
    required ValueChanged<double> onLevel,
    required VoidCallback onEnd,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
