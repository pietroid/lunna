import 'package:agent/src/surface.dart';
import 'package:agent/src/view/answer_card.dart';
import 'package:agent/src/view/cards_peek.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// {@template artifact_peek}
/// An artifact at a glance, in the conversation: the Projetos row as it is
/// (its name, how many of its tasks are done, its deadline and how far
/// along its time is), then its next tasks, at most three, as Lista says
/// them, and Abrir projeto.
///
/// It is drawn for "como está a Tese?", and above a plan that changes a
/// artifact. A plan that deletes one names what goes with it in its own row,
/// so it is never drawn above a delete.
/// {@endtemplate}
class ArtifactPeek extends StatelessWidget {
  /// {@macro artifact_peek}
  const ArtifactPeek({required this.artifact, this.onOpen, super.key});

  final PeekArtifact artifact;

  /// Opens the artifact's page.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final deadline = artifact.deadline;
    final open = artifact.total - artifact.done;
    final more = open - artifact.next.length;
    final days = deadline == null
        ? null
        : DateUtils.dateOnly(
            deadline,
          ).difference(DateUtils.dateOnly(now)).inDays;
    final overdue = days != null && days < 0;
    final left = days == null
        ? null
        : overdue
        ? l10n.artifactOverdue(-days)
        : l10n.artifactDaysLeft(days);

    return AnswerCard(
      footer: onOpen == null
          ? null
          : AppButton.text(
              text: l10n.agentArtifactOpen,
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
                    iconData: AppIcons.artifacts,
                    size: 16,
                    color: AppColors.ink2,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      artifact.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title,
                    ),
                  ),
                  if (artifact.total > 0)
                    Text(
                      l10n.agentArtifactDone(artifact.done, artifact.total),
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
                          ? l10n.artifactNoDeadline
                          : l10n.artifactUntil(
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
                    value: artifact.progressAt(now) ?? 0,
                    minHeight: 3,
                    backgroundColor: AppColors.line,
                    color: overdue ? AppColors.dangerInk : AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (artifact.next.isNotEmpty)
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
                    l10n.agentArtifactNext,
                    if (more > 0) l10n.agentArtifactMore(more),
                  ].join(' · '),
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ),
              for (final card in artifact.next) PeekCardRow(card: card),
            ],
          ),
      ],
    );
  }
}
