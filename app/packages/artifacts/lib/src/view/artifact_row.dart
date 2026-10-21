import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:l10n/l10n.dart';

/// {@template artifact_row}
/// One delivery in the queue: its name and what it is worth, then its kind,
/// its time and its day, and a bar once some of it has been worked.
///
/// The same borderless fill as an artifact's row was, so the list reads as
/// the app's other lists do.
/// {@endtemplate}
class ArtifactRow extends StatelessWidget {
  /// {@macro artifact_row}
  const ArtifactRow({
    required this.artifact,
    required this.now,
    this.onTap,
    super.key,
  });

  /// The delivery.
  final Artifact artifact;

  /// The moment it is drawn at.
  final DateTime now;

  /// Opens its page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = artifact;
    final done = a.isDone;
    final value = a.value;
    final deadline = a.deadline;
    final doneAt = a.doneAt;

    final time = a.doneMinutes > 0 && !done
        ? l10n.artifactTimeDone(
            formatMinutes(l10n, a.doneMinutes),
            formatMinutes(l10n, a.minutes),
          )
        : formatMinutes(l10n, a.minutes);
    final block = a.blockMinutes;
    final parts = [
      a.type?.name ?? l10n.artifactLoose,
      if (a.steps > 0 && !done)
        l10n.artifactSteps(a.stepsDone, a.steps)
      else if (block != null && !done && a.doneMinutes == 0)
        '$time ${l10n.artifactBlocks(formatMinutes(l10n, block))}'
      else
        time,
      if (doneAt != null)
        l10n.artifactsDoneOn(dayName(l10n, doneAt, now))
      else if (deadline != null)
        l10n.artifactDue(dayName(l10n, deadline, now)),
    ];
    final worked = a.steps > 0
        ? a.stepsDone / a.steps
        : a.doneMinutes / (a.minutes == 0 ? 1 : a.minutes);

    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: done ? AppColors.ink2 : AppColors.ink,
                      ),
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: AppSpacing.s3),
                    Text(
                      formatMoney(value),
                      style: AppTypography.label.copyWith(
                        color: done ? AppColors.ink3 : AppColors.ink2,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: done ? AppColors.ink3 : AppColors.ink2,
                ),
              ),
              if (worked > 0 && !done) ...[
                const SizedBox(height: AppSpacing.s3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  child: LinearProgressIndicator(
                    value: worked.clamp(0, 1),
                    minHeight: 3,
                    backgroundColor: AppColors.line,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
