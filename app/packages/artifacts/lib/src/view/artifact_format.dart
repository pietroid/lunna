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
