import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/goal_card.dart';
import 'package:clock/clock.dart';

/// What a suggestion's plan would make, drawn as Objetivos and Entregas
/// draw it ([AgentLinks.preview]): a goal as its [GoalCard], a delivery as
/// its [ArtifactRow]. Nothing in it opens: it is not written down yet.
Widget? drawAgentPreview(BuildContext context, PreviewItem item) {
  final now = clock.now();

  return switch (item) {
    GoalPreview() => GoalCard(
      goal: Goal(
        id: '',
        kind: GoalKind.money,
        target: item.target,
        start: item.start,
        end: item.end,
        done: item.done,
        queued: item.queued,
        queuedCount: item.queuedCount,
      ),
      now: now,
    ),
    ArtifactPreview() => ArtifactRow(
      artifact: Artifact(
        id: '',
        title: item.title,
        minutes: item.minutes,
        createdAt: now,
        deadline: item.deadline,
        value: item.value,
      ),
      now: now,
    ),
    RoutinePreview() => null,
  };
}
