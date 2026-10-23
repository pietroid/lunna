import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:l10n/l10n.dart';

/// {@template artifact_row}
/// One delivery in the queue: its name and what it is worth, then its kind,
/// its time and whether it is on pace, and its two bars, the work done and
/// the time gone ([PaceBars]).
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
    final doneAt = a.doneAt;

    final block = a.blockMinutes;
    final parts = [
      a.type?.name ?? l10n.artifactLoose,
      if (block != null && !done && a.doneMinutes == 0)
        '${formatMinutes(l10n, a.minutes)} '
            '${l10n.artifactBlocks(formatMinutes(l10n, block))}'
      else
        formatMinutes(l10n, a.minutes),
      if (doneAt != null) l10n.artifactsDoneOn(dayName(l10n, doneAt, now)),
    ];
    final behind = isBehind(a, now);

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
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: parts.join(' · ')),
                    if (!done && a.deadline != null) ...[
                      const TextSpan(text: ' · '),
                      TextSpan(
                        text: behind
                            ? l10n.artifactPaceBehind
                            : l10n.artifactPaceOn,
                        style: TextStyle(
                          color: behind ? AppColors.warning : null,
                        ),
                      ),
                    ],
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: done ? AppColors.ink3 : AppColors.ink2,
                ),
              ),
              if (!done) ...[
                const SizedBox(height: AppSpacing.s3),
                PaceBars(artifact: a, now: now),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
