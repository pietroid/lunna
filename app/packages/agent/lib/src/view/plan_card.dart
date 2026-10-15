import 'package:agent/src/models.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template plan_card}
/// A plan, change by change, with the one button that makes it.
///
/// Each line says what it is by its mark (+ for something new, → for a move)
/// and by its colour (the fixed blocks' sand, the routines' blue), and a move
/// shows the hour it had struck through. The accent is spent once, on
/// Aplicar.
/// {@endtemplate}
class PlanCard extends StatelessWidget {
  /// {@macro plan_card}
  const PlanCard({
    required this.plan,
    required this.status,
    required this.onApply,
    required this.onAdjust,
    super.key,
  });

  final AgentPlan plan;

  final PlanStatus status;

  final VoidCallback onApply;

  /// Puts the user back in the field, to say what to change.
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = plan.changes.first.at;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius + 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AppColors.fill,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalised(l10n.longDate(first)),
                      style: AppTypography.labelStrong.copyWith(
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                  Text(
                    l10n.agentChanges(plan.changes.length),
                    style: AppTypography.label,
                  ),
                ],
              ),
            ),
          ),
          for (final change in plan.changes) _ChangeRow(change: change),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: status == PlanStatus.applied
                ? Row(
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
                : Row(
                    children: [
                      Expanded(
                        child: AppButton.text(
                          text: l10n.agentAdjust,
                          color: AppColors.ink,
                          expand: true,
                          onPressed: status == PlanStatus.pending
                              ? onAdjust
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: AppButton(
                          text: l10n.agentApply,
                          expand: true,
                          onPressed: status == PlanStatus.pending
                              ? onApply
                              : null,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final PlanChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (fill, ink) = change.kind.fixed
        ? (AppColors.fixedFill, AppColors.fixedInk)
        : change.routine
        ? (AppColors.routineFill, AppColors.routineInk)
        : change.kind.adds
        ? (AppColors.accentSoft, AppColors.accent)
        : (AppColors.fill, AppColors.ink2);
    final what = switch (change.kind) {
      PlanChangeKind.addTask => l10n.agentChangeAddTask,
      PlanChangeKind.addEvent => l10n.agentChangeAddEvent,
      _ when change.routine => l10n.agentChangeRoutine,
      _ when change.before == null => l10n.agentChangeFromBacklog,
      _ => l10n.agentChangeMoved,
    };
    final quiet = AppTypography.label;
    final before = change.before;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: AppIcon(
                iconData: change.kind.adds
                    ? AppIcons.plus
                    : AppIcons.arrowRight,
                size: 15,
                color: ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(change.title, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: quiet,
                    children: [
                      if (before != null && !change.kind.adds) ...[
                        TextSpan(
                          text: _hhmm(before),
                          style: quiet.copyWith(
                            color: AppColors.ink3,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const TextSpan(text: ' → '),
                        TextSpan(text: _hhmm(change.at)),
                      ] else
                        TextSpan(
                          text: '${_hhmm(change.at)}–${_hhmm(change.end)}',
                        ),
                      TextSpan(text: ' · $what'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

String _capitalised(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
