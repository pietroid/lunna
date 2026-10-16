import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/bloc/projects_cubit.dart';
import 'package:projects/src/models/models.dart';
import 'package:projects/src/view/failure_listener.dart';
import 'package:projects/src/view/project_format.dart';
import 'package:projects/src/view/project_page.dart';

/// {@template projects_page}
/// The Projetos tab: every open project, nearest deadline first, and the
/// finished ones under them.
///
/// Each row is the project's name, how far along its time is, and how many
/// of its tasks are done. A project with no deadline has no bar: there is no
/// stretch of time for it to fill.
/// {@endtemplate}
class ProjectsPage extends StatelessWidget {
  /// {@macro projects_page}
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ProjectsFailureListener(
            child: BlocBuilder<ProjectsCubit, ProjectsState>(
              builder: (context, state) {
                final now = clock.now();
                final open = _byDeadline(state.open);
                final done = state.done;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s5,
                    AppSpacing.s5,
                    AppSpacing.s5,
                    // Room for the bar and the + floating over the list.
                    AppSpacing.s16 * 2,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.shellProjectsTab,
                            style: AppTypography.headline,
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            l10n.projectsOpenCount(open.length),
                            style: AppTypography.label,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    if (open.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.s1),
                        child: Text(
                          l10n.projectsEmpty,
                          style: AppTypography.body.copyWith(
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    for (final project in open) ...[
                      ProjectRow(project: project, now: now),
                      const SizedBox(height: AppSpacing.s2),
                    ],
                    if (done.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s1,
                          AppSpacing.s5,
                          AppSpacing.s1,
                          AppSpacing.s3,
                        ),
                        child: Text(
                          l10n.projectsDoneSection,
                          style: AppTypography.title,
                        ),
                      ),
                      for (final project in done) ...[
                        ProjectRow(project: project, now: now),
                        const SizedBox(height: AppSpacing.s2),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Nearest deadline first; those with none after, in the order they came.
  static List<Project> _byDeadline(List<Project> projects) {
    final dated = [
      for (final p in projects)
        if (p.deadline != null) p,
    ]..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    return [
      ...dated,
      for (final p in projects)
        if (p.deadline == null) p,
    ];
  }
}

/// {@template project_row}
/// One project in the list: a borderless fill with its name, its time and
/// its tasks.
/// {@endtemplate}
class ProjectRow extends StatelessWidget {
  /// {@macro project_row}
  const ProjectRow({required this.project, required this.now, super.key});

  /// The project.
  final Project project;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remaining = remainingLabel(l10n, project, now);
    final overdue = isOverdue(project, now);
    final done = project.isDone;

    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        onTap: () => openProject(context, project.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: done ? AppColors.ink2 : AppColors.ink,
                      ),
                    ),
                  ),
                  if (project.tasks.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.s3),
                    Text(
                      l10n.projectTaskCount(
                        project.doneCount,
                        project.tasks.length,
                      ),
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: done
                          ? l10n.projectDoneOn(
                              AppWheelPicker.dayLabel(
                                l10n,
                                project.doneAt!,
                                now: now,
                              ).toLowerCase(),
                            )
                          : deadlineLabel(l10n, project, now),
                    ),
                    if (remaining != null && !done)
                      TextSpan(
                        text: ' · $remaining',
                        style: overdue
                            ? const TextStyle(color: AppColors.dangerInk)
                            : null,
                      ),
                  ],
                ),
                style: AppTypography.label.copyWith(
                  color: done ? AppColors.ink3 : AppColors.ink2,
                ),
              ),
              if (project.deadline != null && !done) ...[
                const SizedBox(height: AppSpacing.s3),
                ProjectBar(project: project, now: now),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
