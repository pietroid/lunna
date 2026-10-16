import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/bloc/projects_cubit.dart';
import 'package:projects/src/models/models.dart';

/// Asks where [task] goes, and moves it there.
///
/// An hour asks for the day and the hour too. Anything dismissed leaves the
/// task where it was.
Future<void> placeTask(
  BuildContext context,
  Project project,
  ProjectTask task,
) async {
  final cubit = context.read<ProjectsCubit>();
  final place = await showPlaceSheet(context, task);
  if (place == null || !context.mounted) return;

  DateTime? at;
  if (place == TaskPlace.scheduled) {
    final now = clock.now();
    at = await AppWheelPicker.dayAndTime(
      context,
      initial: task.at ?? now,
      earliest: now.subtract(const Duration(minutes: 5)),
    );
    if (at == null) return;
  } else if (place == task.place) {
    return;
  }

  await cubit.placeTask(project.id, task.id, place, at: at);
}

/// Opens the sheet that asks where [task] goes.
Future<TaskPlace?> showPlaceSheet(BuildContext context, ProjectTask task) {
  return showModalBottomSheet<TaskPlace>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => PlaceSheet(task: task),
  );
}

/// {@template place_sheet}
/// Where a project's task is: only in the project, in the backlog, in the
/// queue, or at an hour.
///
/// A project's tasks start in the project, out of the day's sight, so a
/// project with twenty tasks does not drop twenty tasks on the backlog.
/// This is how one of them is let out, and how it is taken back.
/// {@endtemplate}
class PlaceSheet extends StatelessWidget {
  /// {@macro place_sheet}
  const PlaceSheet({required this.task, super.key});

  /// The task being placed.
  final ProjectTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s5,
            AppSpacing.s5,
            AppSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.placeTitle, style: AppTypography.title),
              const SizedBox(height: AppSpacing.s1),
              Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.s4),
              for (final place in const [
                TaskPlace.project,
                TaskPlace.backlog,
                TaskPlace.queue,
                TaskPlace.scheduled,
                TaskPlace.done,
              ])
                _Option(
                  place: place,
                  current: place == task.place,
                  onTap: () => Navigator.of(context).pop(place),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.place,
    required this.current,
    required this.onTap,
  });

  final TaskPlace place;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title, help) = switch (place) {
      TaskPlace.project => (
        AppIcons.things,
        l10n.placeProject,
        l10n.placeProjectHelp,
      ),
      TaskPlace.backlog => (
        AppIcons.archive,
        l10n.placeBacklog,
        l10n.placeBacklogHelp,
      ),
      TaskPlace.queue => (AppIcons.time, l10n.placeQueue, l10n.placeQueueHelp),
      TaskPlace.done => (AppIcons.check, l10n.placeDone, l10n.placeDoneHelp),
      TaskPlace.scheduled => (
        AppIcons.calendar,
        l10n.placeScheduled,
        l10n.placeScheduledHelp,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(
                iconData: icon,
                size: AppSpacing.s5,
                color: current ? AppColors.accent : AppColors.ink2,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyStrong),
                  const SizedBox(height: 2),
                  Text(help, style: AppTypography.label),
                ],
              ),
            ),
            if (current)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.s2, top: 2),
                child: AppIcon(
                  iconData: AppIcons.check,
                  size: AppSpacing.s4,
                  color: AppColors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
