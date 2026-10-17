import 'package:agent/src/models.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template plan_card}
/// A plan, change by change, with the one button that makes it.
///
/// Each line says what it is by its mark (+ for something new, → for a move)
/// and by its colour (the fixed blocks' sand, the routines' blue), and a move
/// shows the hour it had struck through. Then, in grey with ↓, what the plan
/// pushes later: then the card is a question, and its buttons say so
/// (Outro horário, Mover). The accent is spent once, on the button that
/// applies it.
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

  /// Puts the user back in the field, to say what to change, or which other
  /// hour.
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = plan.changes.map((it) => it.at).nonNulls.firstOrNull;

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
                      first == null
                          ? l10n.stageBacklog
                          : _capitalised(l10n.longDate(first)),
                      style: AppTypography.labelStrong.copyWith(
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                  Text(
                    plan.pushed.isEmpty
                        ? l10n.agentChanges(plan.changes.length)
                        : '${l10n.agentChanges(plan.changes.length)} · '
                              '${l10n.agentPushedCount(plan.pushed.length)}',
                    style: AppTypography.label,
                  ),
                ],
              ),
            ),
          ),
          for (final change in plan.changes) _ChangeRow(change: change),
          for (final pushed in plan.pushed) _PushedRow(pushed: pushed),
          if (plan.assumed.isNotEmpty) _AssumedRow(assumed: plan.assumed),
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
                          text: plan.pushed.isEmpty
                              ? l10n.agentAdjust
                              : l10n.agentOtherTime,
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
                          text: plan.pushed.isEmpty
                              ? l10n.agentApply
                              : l10n.agentPush,
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
      PlanChangeKind.toBacklog when change.id == null =>
        l10n.agentChangeAddTask,
      PlanChangeKind.toBacklog => l10n.agentChangeMoved,
      _ when change.place != null => _where(l10n, change.place!),
      PlanChangeKind.addTask => l10n.agentChangeAddTask,
      PlanChangeKind.addEvent => l10n.agentChangeAddEvent,
      _ when change.routine => l10n.agentChangeRoutine,
      _ when change.before == null => l10n.agentChangeFromBacklog,
      _ => l10n.agentChangeMoved,
    };
    final quiet = AppTypography.label;
    final before = change.before;
    // A move across days names both, so a wrong day shows before Aplicar.
    final at = change.at;
    final days = before != null && at != null && !_sameDay(before, at);
    String hour(DateTime at) =>
        days ? '${_weekday(l10n, at)} ${_hhmm(at)}' : _hhmm(at);

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
                          text: hour(before),
                          style: quiet.copyWith(
                            color: AppColors.ink3,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const TextSpan(text: ' → '),
                        TextSpan(
                          text: at == null ? l10n.stageBacklog : hour(at),
                        ),
                      ] else if (at == null)
                        TextSpan(text: l10n.stageBacklog)
                      else
                        TextSpan(text: '${_hhmm(at)}–${_hhmm(change.end!)}'),
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

/// A task the plan pushes later: quiet, since the plan does not name it.
class _PushedRow extends StatelessWidget {
  const _PushedRow({required this.pushed});

  final PushedTask pushed;

  @override
  Widget build(BuildContext context) {
    final quiet = AppTypography.label;

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
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: AppIcon(
                iconData: AppIcons.pushed,
                size: 15,
                color: AppColors.ink2,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pushed.title, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: quiet,
                    children: [
                      TextSpan(
                        text: _hhmm(pushed.before),
                        style: quiet.copyWith(
                          color: AppColors.ink3,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' → ${_hhmm(pushed.at)} · '
                            '${context.l10n.agentChangePushed}',
                      ),
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

/// What the plan took without being told, said once, quietly, above the
/// buttons that let it be changed.
class _AssumedRow extends StatelessWidget {
  const _AssumedRow({required this.assumed});

  final List<PlanAssumption> assumed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = [
      for (final it in assumed)
        switch (it.kind) {
          PlanAssumptionKind.minutes => l10n.durationMinutes(it.minutes ?? 0),
          PlanAssumptionKind.today => l10n.agentAssumedToday,
          PlanAssumptionKind.endOfQueue => l10n.agentAssumedEnd,
        },
    ];
    final what = parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            child: Center(
              child: AppIcon(
                iconData: AppIcons.pen,
                size: 13,
                color: AppColors.ink3,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              l10n.agentAssumed(what),
              style: AppTypography.label.copyWith(color: AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// {@template plan_line}
/// A plan from a conversation already over, in one line: what it changed and
/// what became of it. Read only.
/// {@endtemplate}
class PlanLine extends StatelessWidget {
  /// {@macro plan_line}
  const PlanLine({required this.plan, required this.status, super.key});

  final AgentPlan plan;

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final applied = status == PlanStatus.applied;
    final only = plan.changes.length == 1 ? plan.changes.single : null;
    final what = only == null
        ? l10n.agentChanges(plan.changes.length)
        : only.at == null
        ? '${only.title} · ${l10n.stageBacklog}'
        : '${only.title} ${_hhmm(only.at!)}';
    final changes = plan.pushed.isEmpty
        ? what
        : '$what · ${l10n.agentPushedCount(plan.pushed.length)}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        children: [
          AppIcon(
            iconData: applied ? AppIcons.check : AppIcons.undo,
            size: 14,
            color: applied ? AppColors.success : AppColors.ink3,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              l10n.agentPlanSummary(
                changes,
                switch (status) {
                  PlanStatus.applied => l10n.agentPlanApplied,
                  PlanStatus.undone => l10n.agentPlanUndone,
                  _ => l10n.agentPlanNotApplied,
                },
              ),
              style: AppTypography.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a place in the queue is, by the cards around it.
String _where(AppLocalizations l10n, PlanPlace place) =>
    switch ((place.after, place.before)) {
      (final after?, final before?) => l10n.agentPlaceBetween(after, before),
      (final after?, null) => l10n.agentPlaceAfter(after),
      (null, final before?) => l10n.agentPlaceBefore(before),
      (null, null) => l10n.agentPlaceEnd,
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekday(AppLocalizations l10n, DateTime at) =>
    l10n.weekdaysShort.split(',')[at.weekday - 1];

String _hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

String _capitalised(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
