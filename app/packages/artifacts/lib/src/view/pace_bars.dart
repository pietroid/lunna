import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_format.dart';
import 'package:l10n/l10n.dart';

/// How far a delivery's work has got, from 0 to 1: its tasks done out of
/// its tasks, or, with none written down, its minutes worked.
double workDone(Artifact artifact) {
  if (artifact.isDone) return 1;
  if (artifact.steps > 0) return artifact.stepsDone / artifact.steps;
  if (artifact.minutes == 0) return 0;
  return (artifact.doneMinutes / artifact.minutes).clamp(0, 1);
}

/// How far the work is behind the time before it reads as behind: a
/// delivery a step or so short of its time is still on pace.
const paceSlack = 0.15;

/// Whether the time gone by is ahead of the work done by more than
/// [paceSlack]: half the time gone and a quarter of the work done.
bool isBehind(Artifact artifact, DateTime now) {
  final time = artifact.progressAt(now);
  if (time == null || artifact.isDone) return false;
  return time - workDone(artifact) > paceSlack;
}

/// {@template pace_bars}
/// Two bars of the same length, one over the other: the work done and the
/// time gone, from the day it was written down to the end of its deadline.
///
/// Neither is hours. The work is the share of its tasks done and the time
/// the share of its days gone, so the two are read against each other: a
/// delivery half done with half its time gone is on pace and the bars end
/// together; ten tasks, one done and a day left, and the time bar runs far
/// past the work. The time bar turns the warning colour when it is ahead
/// by more than [paceSlack], and the danger colour once the day has passed.
///
/// With no deadline there is only the work.
/// {@endtemplate}
class PaceBars extends StatelessWidget {
  /// {@macro pace_bars}
  const PaceBars({required this.artifact, required this.now, super.key});

  /// The delivery.
  final Artifact artifact;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = artifact;
    final time = a.progressAt(now);
    final remaining = remainingLabel(l10n, a, now);
    final timeColor = isOverdue(a, now)
        ? AppColors.dangerInk
        : isBehind(a, now)
        ? AppColors.warning
        : AppColors.ink3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bar(
          label: l10n.artifactPaceDone,
          value: workDone(a),
          color: AppColors.accent,
          trailing: a.steps > 0
              ? l10n.artifactSteps(a.stepsDone, a.steps)
              : '${(workDone(a) * 100).round()}%',
          trailingColor: AppColors.ink2,
        ),
        if (time != null && remaining != null) ...[
          const SizedBox(height: AppSpacing.s1),
          _Bar(
            label: l10n.artifactPaceTime,
            value: time,
            color: timeColor,
            trailing: remaining,
            trailingColor: timeColor == AppColors.ink3
                ? AppColors.ink2
                : timeColor,
          ),
        ],
      ],
    );
  }
}

/// One of the two: its name, the bar, and what it counts.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.color,
    required this.trailing,
    required this.trailingColor,
  });

  final String label;
  final double value;
  final Color color;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: AppTypography.caption),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 4,
              backgroundColor: AppColors.line,
              color: color,
            ),
          ),
        ),
        // A fixed width, so both bars end in the same place and can be
        // read against each other.
        SizedBox(
          width: 104,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: trailingColor),
          ),
        ),
      ],
    );
  }
}
