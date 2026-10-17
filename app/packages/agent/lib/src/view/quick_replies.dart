import 'package:agent/src/models.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template quick_replies}
/// The answers the agent offers, one pill each. A tap makes that answer's
/// plan, with no other turn; typing something else is always there, in the
/// composer under them.
///
/// None is the accent: they are choices of equal weight. Once one is made,
/// the rest go and it stays as one ticked line.
/// {@endtemplate}
class QuickReplies extends StatelessWidget {
  /// {@macro quick_replies}
  const QuickReplies({
    required this.options,
    required this.status,
    required this.onPick,
    this.chosen,
    super.key,
  });

  final List<QuickReply> options;

  final PlanStatus status;

  /// The plan taken, when one was.
  final String? chosen;

  final ValueChanged<QuickReply> onPick;

  @override
  Widget build(BuildContext context) {
    final taken = options.where((it) => it.plan.id == chosen).firstOrNull;
    if (taken != null && status == PlanStatus.applied) {
      return Row(
        children: [
          const AppIcon(
            iconData: AppIcons.check,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              context.l10n.agentPlanSummary(
                taken.label,
                context.l10n.agentPlanApplied,
              ),
              style: AppTypography.labelStrong.copyWith(
                color: AppColors.success,
              ),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final option in options)
          _Pill(
            label: option.label,
            busy: status == PlanStatus.applying && option.plan.id == chosen,
            onTap: status == PlanStatus.pending ? () => onPick(option) : null,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.busy, this.onTap});

  final String label;

  final bool busy;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(999),
    );

    return Material(
      color: AppColors.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s2 + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Text(
                label,
                style: AppTypography.labelStrong.copyWith(
                  color: onTap == null && !busy
                      ? AppColors.ink3
                      : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
