import 'package:agent/src/models.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template agent_wash}
/// The agent's own card: the accent's wash, nothing else. A suggestion's
/// header (its mark and its words) and its actions are drawn in it; what
/// the plan would make is drawn between them, outside it.
/// {@endtemplate}
class AgentWash extends StatelessWidget {
  /// {@macro agent_wash}
  const AgentWash({required this.child, this.padding, super.key});

  final Widget child;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(AppSpacing.s4),
    decoration: BoxDecoration(
      color: AppColors.accentWash,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
    ),
    child: child,
  );
}

/// {@template offer_actions}
/// The foot of a reply drawn in three parts: what Aplicar makes that the
/// preview above can't show, then **Ajustar** and **Aplicar**, in the
/// agent's wash. The same on Feed and in the conversation, so the buttons
/// always act on what was just drawn.
/// {@endtemplate}
class OfferActions extends StatelessWidget {
  /// {@macro offer_actions}
  const OfferActions({
    required this.status,
    required this.onAdjust,
    required this.onApply,
    this.applies,
    super.key,
  });

  /// The line above the buttons ("Aplicar anota a meta e as duas entregas.").
  final String? applies;

  final PlanStatus status;

  /// Feed: opens the conversation on the turn. The conversation: answers it.
  final VoidCallback onAdjust;

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final applies = this.applies;
    final pending = status == PlanStatus.pending;

    return AgentWash(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (applies != null) ...[
            Text(
              applies,
              style: AppTypography.label.copyWith(color: AppColors.ink2),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          if (status == PlanStatus.applied)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(
                  iconData: AppIcons.check,
                  size: AppSpacing.s4,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  l10n.agentApplied,
                  style: AppTypography.labelStrong.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppButton.text(
                    text: l10n.agentAdjust,
                    color: AppColors.ink,
                    expand: true,
                    onPressed: pending ? onAdjust : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: AppButton(
                    text: l10n.agentApply,
                    expand: true,
                    onPressed: pending ? onApply : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
