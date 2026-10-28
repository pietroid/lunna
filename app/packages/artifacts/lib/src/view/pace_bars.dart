import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_format.dart';
import 'package:l10n/l10n.dart';

/// How far a delivery's work has got, from 0 to 1: the minutes of its
/// tasks done out of its whole time, so a three-hour task weighs twelve
/// times a fifteen-minute one, as the clock it is read against does.
double workDone(Artifact artifact) {
  if (artifact.isDone) return 1;
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
/// Under it, a key in the same two colours: what the green counts (the
/// time done of the whole) and what the red is running to (the day it is
/// due), the latter in the danger ink once it is urgent ([isUrgent]). With
/// no deadline, or not begun, there is only the green.
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
    final deadline = a.deadline;
    final work = workDone(a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaceBar(time: time, done: work),
        const SizedBox(height: AppSpacing.s2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: PaceKey(
                color: AppColors.paceDone,
                text: l10n.artifactTimeDone(
                  formatMinutes(l10n, a.doneMinutes),
                  formatMinutes(l10n, a.minutes),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            if (time != null && deadline != null)
              Flexible(
                child: PaceKey(
                  color: AppColors.paceTime,
                  text: isOverdue(a, now)
                      ? remainingLabel(l10n, a, now)!
                      : deadlineLabel(l10n, a, now),
                  ink: isUrgent(a, now) ? AppColors.dangerInk : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// {@template pace_bar}
/// The bar alone: [time] in red ([AppColors.paceTime]) and over it [done]
/// in green ([AppColors.paceDone]), each a share from 0 to 1. A delivery
/// reads its work against its days; a goal its money against the money
/// its days ask for.
/// {@endtemplate}
class PaceBar extends StatelessWidget {
  /// {@macro pace_bar}
  const PaceBar({required this.done, this.time, super.key});

  /// The share of the time gone; null draws no red.
  final double? time;

  /// The share done.
  final double done;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.line),
            if (time != null) _Fill(value: time, color: AppColors.paceTime),
            _Fill(value: done, color: AppColors.paceDone),
          ],
        ),
      ),
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
class PaceKey extends StatelessWidget {
  /// Creates the key.
  const PaceKey({
    required this.color,
    required this.text,
    this.ink,
    super.key,
  });

  /// The bar's colour.
  final Color color;

  /// What it counts.
  final String text;

  /// The text's colour, when not the quiet one.
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
        Flexible(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(color: ink ?? AppColors.ink2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Whether it has been begun: moved into Em andamento, or a task of it
/// begun on the day. Moved back to Não iniciadas, it is not, whatever was
/// done of it.
bool isStarted(Artifact artifact) => artifact.startedAt != null;

/// Whether a delivery under way is late: its day has gone by, or its time
/// is ahead of its work by more than [paceSlack]. Entregas draws it first,
/// on a red-tinged card tagged Urgente.
bool isUrgent(Artifact artifact, DateTime now) =>
    isStarted(artifact) &&
    (isOverdue(artifact, now) || isBehind(artifact, now));

/// How far the red runs past the green at [now]: the share of the time gone
/// less the share of the work done. Negative when the work is ahead; with
/// no deadline there is no time, so only the work counts.
double lagOf(Artifact artifact, DateTime now) =>
    (artifact.progressAt(now) ?? 0) - workDone(artifact);

/// [queue] (in its order) cut in two, as Entregas draws it: what is under
/// way, the urgent ones first and then the one most behind its time first,
/// and what has not been begun,
/// left in the queue's order, which is the one a drag sets.
({List<Artifact> started, List<Artifact> waiting}) progressGroups(
  List<Artifact> queue,
  DateTime now,
) {
  final order = {for (final (i, a) in queue.indexed) a.id: i};
  final started = queue.where(isStarted).toList()
    ..sort((a, b) {
      final urgent = isUrgent(a, now);
      if (urgent != isUrgent(b, now)) return urgent ? -1 : 1;
      final byLag = lagOf(b, now).compareTo(lagOf(a, now));
      return byLag != 0 ? byLag : order[a.id]!.compareTo(order[b.id]!);
    });
  return (
    started: started,
    waiting: queue.where((a) => !isStarted(a)).toList(),
  );
}

/// Where in [queue] a delivery lands when it is dropped at [to] among
/// [rows], the part of the queue drawn around it: just before the row it
/// was let go above, or just after the last one, counted in [queue] once
/// [id] has left it, which is how a move counts.
int queueIndexOf(List<Artifact> queue, List<Artifact> rows, String id, int to) {
  final rest = [...queue]..removeWhere((a) => a.id == id);
  final others = [...rows]..removeWhere((a) => a.id == id);
  if (others.isEmpty) return rest.length;
  if (to < others.length) {
    return rest.indexWhere((a) => a.id == others[to].id);
  }
  return rest.indexWhere((a) => a.id == others.last.id) + 1;
}
