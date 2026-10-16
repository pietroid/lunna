import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/models/models.dart';

/// "até sex, 30 out", or "Sem prazo".
String deadlineLabel(AppLocalizations l10n, Project project, DateTime now) {
  final deadline = project.deadline;
  if (deadline == null) return l10n.projectNoDeadline;

  return l10n.projectUntil(
    AppWheelPicker.dayLabel(l10n, deadline, now: now).toLowerCase(),
  );
}

/// "faltam 14 dias", "termina hoje", "atrasado 2 dias"; null with no
/// deadline.
String? remainingLabel(AppLocalizations l10n, Project project, DateTime now) {
  final days = project.daysLeftAt(now);
  if (days == null) return null;
  if (days < 0) return l10n.projectOverdue(-days);
  return l10n.projectDaysLeft(days);
}

/// Whether the deadline has gone by with the project still open.
bool isOverdue(Project project, DateTime now) =>
    !project.isDone && (project.daysLeftAt(now) ?? 0) < 0;

/// {@template project_bar}
/// How much of a project's time has gone by: a thin line, the same as a
/// running block's, red once the deadline has passed.
/// {@endtemplate}
class ProjectBar extends StatelessWidget {
  /// {@macro project_bar}
  const ProjectBar({required this.project, required this.now, super.key});

  /// The project.
  final Project project;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(project, now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: LinearProgressIndicator(
        value: project.isDone ? 1 : project.progressAt(now) ?? 0,
        minHeight: 3,
        backgroundColor: AppColors.line,
        color: project.isDone
            ? AppColors.ink3
            : overdue
            ? AppColors.dangerInk
            : AppColors.accent,
      ),
    );
  }
}
