import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_format.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:l10n/l10n.dart';

/// {@template artifact_row}
/// One delivery in Entregas: its name, and nothing under it but what tells
/// how it is going.
///
/// Under way, its pace bar ([PaceBars]): the time done of the whole in
/// green over the time gone in red, keyed with the day it is due. Late
/// ([isUrgent]), the card takes a little red ([AppColors.urgentFill]) and
/// a tag says Urgente. Not begun, no clock runs yet, so there is no bar:
/// the name, and its time and its day at the end of the line. Delivered,
/// the day it was.
///
/// The same borderless fill as the app's other lists.
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
    final doneAt = a.doneAt;
    final started = isStarted(a) && !done;
    final urgent = isUrgent(a, now) && !done;

    // At the end of the name's line: a tag when it is late, the day it was
    // delivered, or, not begun, its time and its day.
    final Widget? trailing;
    if (urgent) {
      trailing = AppTag(
        text: l10n.artifactUrgent,
        iconData: AppIcons.warning,
        fill: AppColors.danger,
        ink: AppColors.dangerInk,
      );
    } else if (doneAt != null) {
      trailing = _Aside(text: l10n.artifactsDoneOn(dayName(l10n, doneAt, now)));
    } else if (!started) {
      trailing = _Aside(
        text: [
          formatMinutes(l10n, a.minutes),
          if (a.deadline != null) deadlineLabel(l10n, a, now),
        ].join(' · '),
        ink: isOverdue(a, now) ? AppColors.dangerInk : null,
      );
    } else {
      trailing = null;
    }

    return Material(
      color: urgent ? AppColors.urgentFill : AppColors.fill,
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
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.s3),
                    trailing,
                  ],
                ],
              ),
              if (started) ...[
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

/// What a row says at the end of its name's line, in the quiet ink.
class _Aside extends StatelessWidget {
  const _Aside({required this.text, this.ink});

  final String text;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: AppTypography.label.copyWith(color: ink ?? AppColors.ink2),
    );
  }
}
