import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:l10n/l10n.dart';

/// "até sex, 30 out", or "Sem prazo".
String deadlineLabel(AppLocalizations l10n, Artifact artifact, DateTime now) {
  final deadline = artifact.deadline;
  if (deadline == null) return l10n.artifactNoDeadline;

  return l10n.artifactUntil(
    AppWheelPicker.dayLabel(l10n, deadline, now: now).toLowerCase(),
  );
}

/// "faltam 14 dias", "termina hoje", "atrasado 2 dias"; null with no
/// deadline.
String? remainingLabel(AppLocalizations l10n, Artifact artifact, DateTime now) {
  final days = artifact.daysLeftAt(now);
  if (days == null) return null;
  if (days < 0) return l10n.artifactOverdue(-days);
  return l10n.artifactDaysLeft(days);
}

/// Whether the deadline has gone by with the artifact still open.
bool isOverdue(Artifact artifact, DateTime now) =>
    !artifact.isDone && (artifact.daysLeftAt(now) ?? 0) < 0;

/// {@template artifact_bar}
/// How much of an artifact's time has gone by: a thin line, the same as a
/// running block's, red once the deadline has passed.
/// {@endtemplate}
class ArtifactBar extends StatelessWidget {
  /// {@macro artifact_bar}
  const ArtifactBar({required this.artifact, required this.now, super.key});

  /// The artifact.
  final Artifact artifact;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(artifact, now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: LinearProgressIndicator(
        value: artifact.isDone ? 1 : artifact.progressAt(now) ?? 0,
        minHeight: 3,
        backgroundColor: AppColors.line,
        color: artifact.isDone
            ? AppColors.ink3
            : overdue
            ? AppColors.dangerInk
            : AppColors.accent,
      ),
    );
  }
}
