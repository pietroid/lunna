import 'package:agent/src/surface.dart';
import 'package:agent/src/view/answer_card.dart';
import 'package:agent/src/view/cards_peek.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// {@template project_peek}
/// A project at a glance, in the conversation: the Projetos row as it is
/// (its name, how many of its tasks are done, its deadline and how far
/// along its time is), then its next tasks, at most three, as Lista says
/// them, and Abrir projeto.
///
/// It is drawn for "como está a Tese?", and above a plan that changes a
/// project. A plan that deletes one names what goes with it in its own row,
/// so it is never drawn above a delete.
/// {@endtemplate}
class ProjectPeek extends StatelessWidget {
  /// {@macro project_peek}
  const ProjectPeek({required this.project, this.onOpen, super.key});

  final PeekProject project;

  /// Opens the project's page.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final deadline = project.deadline;
    final open = project.total - project.done;
    final more = open - project.next.length;
    final days = deadline == null
        ? null
        : DateUtils.dateOnly(
            deadline,
          ).difference(DateUtils.dateOnly(now)).inDays;
    final overdue = days != null && days < 0;
    final left = days == null
        ? null
        : overdue
        ? l10n.projectOverdue(-days)
        : l10n.projectDaysLeft(days);

    return AnswerCard(
      footer: onOpen == null
          ? null
          : AppButton.text(
              text: l10n.agentProjectOpen,
              color: AppColors.ink,
              expand: true,
              onPressed: onOpen,
            ),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppIcon(
                    iconData: AppIcons.things,
                    size: 16,
                    color: AppColors.ink2,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title,
                    ),
                  ),
                  if (project.total > 0)
                    Text(
                      l10n.agentProjectDone(project.done, project.total),
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: deadline == null
                          ? l10n.projectNoDeadline
                          : l10n.projectUntil(
                              AppWheelPicker.dayLabel(
                                l10n,
                                deadline,
                                now: now,
                              ).toLowerCase(),
                            ),
                    ),
                    if (left != null)
                      TextSpan(
                        text: ' · $left',
                        style: overdue
                            ? const TextStyle(color: AppColors.dangerInk)
                            : null,
                      ),
                  ],
                ),
                style: AppTypography.label.copyWith(color: AppColors.ink2),
              ),
              if (deadline != null) ...[
                const SizedBox(height: AppSpacing.s3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  child: LinearProgressIndicator(
                    value: project.progressAt(now) ?? 0,
                    minHeight: 3,
                    backgroundColor: AppColors.line,
                    color: overdue ? AppColors.dangerInk : AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (project.next.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s3,
                  AppSpacing.s4,
                  0,
                ),
                child: Text(
                  [
                    l10n.agentProjectNext,
                    if (more > 0) l10n.agentProjectMore(more),
                  ].join(' · '),
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ),
              for (final card in project.next) PeekCardRow(card: card),
            ],
          ),
      ],
    );
  }
}
