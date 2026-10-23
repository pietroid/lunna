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
/// One bar holding two: the time gone, from the day the delivery was
/// written down to the end of its deadline, in red ([AppColors.paceTime]),
/// and over it the work done, in green ([AppColors.paceDone]).
///
/// Neither is hours. The work is the share of its tasks done and the time
/// the share of its days gone, so the two are read against each other by
/// which one shows: green covering the red is work ahead of the clock, and
/// red showing past the green is work lagging behind it, by as much as
/// shows. A delivery half done with half its time gone is all green.
///
/// Under it, a key in the same two colours: what the green counts (tasks
/// done) and what the red is running to (when it ends), the latter in the
/// danger ink once the day has passed. With no deadline there is only the
/// green.
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
    final work = workDone(a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.line),
                if (time != null) _Fill(value: time, color: AppColors.paceTime),
                _Fill(value: work, color: AppColors.paceDone),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            _Key(
              color: AppColors.paceDone,
              text: a.steps > 0
                  ? l10n.artifactSteps(a.stepsDone, a.steps)
                  : '${(work * 100).round()}%',
            ),
            const Spacer(),
            if (time != null && remaining != null)
              _Key(
                color: AppColors.paceTime,
                text: remaining,
                ink: isOverdue(a, now) ? AppColors.dangerInk : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// One of the two, from the bar's start to [value] of its length.
class _Fill extends StatelessWidget {
  const _Fill({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0, 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
      ),
    );
  }
}

/// A dot in a bar's colour and what that bar counts.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text, this.ink});

  final Color color;
  final String text;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s1 + 2),
        Text(
          text,
          style: AppTypography.caption.copyWith(color: ink ?? AppColors.ink2),
        ),
      ],
    );
  }
}
