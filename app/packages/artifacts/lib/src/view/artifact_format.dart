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

/// The day a task is due by, as the corner of its card says it, where a
/// task with an hour says its hour: "hoje"; the day's name in the week of
/// [now] (Monday to Sunday), "quinta-feira"; else the date, "12/nov"; and
/// "para ontem" once it has gone by. Null with no deadline.
String? dueLabel(AppLocalizations l10n, Artifact artifact, DateTime now) {
  final deadline = artifact.deadline;
  if (deadline == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(deadline.year, deadline.month, deadline.day);
  if (day.isBefore(today)) return l10n.dueYesterday;
  if (day == today) return l10n.dueToday;
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
  if (day.isBefore(nextMonday)) {
    return l10n.weekdaysLong.split(',')[day.weekday - 1];
  }
  return l10n.dueDate(
    day.day.toString().padLeft(2, '0'),
    l10n.monthsShort.split(',')[day.month - 1],
  );
}
