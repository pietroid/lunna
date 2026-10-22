import 'package:agent/src/models.dart';
import 'package:agent/src/view/answer_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart' show durationLabel;

/// {@template plan_card}
/// A plan, change by change, with the one button that makes it.
///
/// Each line says what it is by its mark (+ for something new, → for a move,
/// the pen for a new name or length, the note for notes, ✓ for done, the bin
/// for a delete) and by its colour (the fixed blocks' sand, the routines'
/// blue, red for what goes), and shows what it had struck through. Deletes
/// come first, named in full with whatever goes with them, and the button
/// then says Apagar, in red. Then, in grey with ↓, what the plan pushes
/// later: then the card is a question, and its buttons say so (Outro
/// horário, Mover). The accent is spent once, on the button that applies it.
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
    final changes = [
      ...plan.changes.where((it) => it.kind.deletes),
      ...plan.changes.where((it) => !it.kind.deletes),
    ];
    final deletes = changes.first.kind.deletes;
    final first = changes.map((it) => it.at).nonNulls.firstOrNull;
    final count = l10n.agentChanges(changes.length);
    // The day it lands on, when it lands on one; otherwise only how much.
    final (title, trailing) = first != null
        ? (_capitalised(l10n.longDate(first)), count)
        : changes.any((it) => it.kind == PlanChangeKind.toBacklog)
        ? (l10n.stageBacklog, count)
        : (_capitalised(count), null);

    return AnswerCard(
      title: title,
      trailing: plan.pushed.isEmpty
          ? trailing
          : [?trailing, l10n.agentPushedCount(plan.pushed.length)].join(' · '),
      footer: Padding(
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
                      onPressed: status == PlanStatus.pending ? onAdjust : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: AppButton(
                      text: deletes
                          ? l10n.agentApplyDelete
                          : plan.pushed.isEmpty
                          ? l10n.agentApply
                          : l10n.agentPush,
                      color: deletes ? AppColors.dangerInk : AppColors.accent,
                      expand: true,
                      onPressed: status == PlanStatus.pending ? onApply : null,
                    ),
                  ),
                ],
              ),
      ),
      children: [
        for (final change in changes) _ChangeRow(change: change),
        for (final pushed in plan.pushed) _PushedRow(pushed: pushed),
        if (plan.assumed.isNotEmpty) _AssumedRow(assumed: plan.assumed),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final PlanChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quiet = AppTypography.label;
    final struck = quiet.copyWith(
      color: AppColors.ink3,
      decoration: TextDecoration.lineThrough,
    );

    switch (change.kind) {
      case PlanChangeKind.edit:
        final was = change.was;
        final wasMinutes = change.wasMinutes;
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.pen),
          title: change.title,
          detail: TextSpan(
            children: [
              if (was != null) ...[
                TextSpan(text: was, style: struck),
                TextSpan(text: ' · ${l10n.agentChangeRenamed}'),
              ],
              if (was != null && wasMinutes != null) const TextSpan(text: '\n'),
              if (wasMinutes != null) ...[
                TextSpan(text: durationLabel(l10n, wasMinutes), style: struck),
                TextSpan(
                  text:
                      ' → ${durationLabel(l10n, change.minutes)}'
                      ' · ${l10n.agentChangeLength}',
                ),
              ],
            ],
          ),
        );
      case PlanChangeKind.note:
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.note),
          title: change.title,
          detail: TextSpan(text: l10n.agentChangeNotes),
          below: _Added(text: change.note ?? ''),
        );
      case PlanChangeKind.done:
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.check, ink: AppColors.success),
          title: change.title,
          detail: TextSpan(text: _hourOr(l10n, l10n.agentChangeDone)),
        );
      case PlanChangeKind.remove:
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.trash,
            fill: AppColors.danger,
            ink: AppColors.dangerInk,
          ),
          title: change.title,
          struck: true,
          detail: TextSpan(text: _hourOr(l10n, l10n.agentChangeRemove)),
        );
      case PlanChangeKind.addArtifact:
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.artifacts,
            fill: AppColors.accentSoft,
            ink: AppColors.accent,
          ),
          title: change.title,
          detail: TextSpan(
            text: [
              l10n.agentChangeNewArtifact,
              if (change.deadline != null)
                l10n.artifactUntil(_ddmm(change.deadline!)),
            ].join(' · '),
          ),
          below: change.takes.isEmpty ? null : _Along(titles: change.takes),
        );
      case PlanChangeKind.editArtifact:
        final was = change.was;
        final wasDeadline = change.wasDeadline;
        final deadline = change.deadline;
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.artifacts),
          title: change.title,
          detail: TextSpan(
            children: [
              if (was != null) ...[
                TextSpan(text: was, style: struck),
                TextSpan(text: ' · ${l10n.agentChangeRenamed}'),
              ] else if (deadline != null || wasDeadline != null) ...[
                TextSpan(text: '${l10n.agentChangeDeadline} '),
                if (wasDeadline != null) ...[
                  TextSpan(text: _ddmm(wasDeadline), style: struck),
                  const TextSpan(text: ' → '),
                ],
                TextSpan(
                  text: deadline == null
                      ? l10n.artifactNoDeadline.toLowerCase()
                      : _ddmm(deadline),
                ),
              ] else
                TextSpan(text: l10n.agentChangeArtifactDone),
            ],
          ),
        );
      case PlanChangeKind.removeArtifact:
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.trash,
            fill: AppColors.danger,
            ink: AppColors.dangerInk,
          ),
          title: change.title,
          struck: true,
          detail: TextSpan(
            text: l10n.agentChangeRemoveArtifact(change.takes.length),
          ),
          below: change.takes.isEmpty
              ? null
              : _Along(titles: change.takes, going: true),
        );
      case PlanChangeKind.deliver:
        final value = change.value;
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.check, ink: AppColors.success),
          title: change.title,
          detail: TextSpan(
            text: [
              l10n.agentChangeArtifactDone,
              if (value != null) _reais(value),
              if (change.takes.isNotEmpty)
                l10n.agentChangeOpenLeft(change.takes.length),
            ].join(' · '),
          ),
          below: change.takes.isEmpty ? null : _Along(titles: change.takes),
        );
      case PlanChangeKind.moveArtifact:
        final place = change.place;
        return AnswerRow(
          mark: const AnswerMark(icon: AppIcons.arrowRight),
          title: change.title,
          detail: TextSpan(
            text: switch ((place?.after, place?.before)) {
              (_, final before?) => l10n.agentChangeArtifactBefore(before),
              (final after?, null) => l10n.agentChangeArtifactAfter(after),
              _ => l10n.agentPlaceEnd,
            },
          ),
        );
      case PlanChangeKind.addKind:
        final shelf = change.shelf;
        final value = change.value;
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.plus,
            fill: AppColors.accentSoft,
            ink: AppColors.accent,
          ),
          title: change.title,
          detail: TextSpan(
            text: [
              l10n.agentChangeNewKind,
              if (shelf != null && shelf.isNotEmpty) shelf,
              if (change.minutes > 0) durationLabel(l10n, change.minutes),
              if (value != null) _reais(value),
            ].join(' · '),
          ),
        );
      case PlanChangeKind.addGoal:
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.plus,
            fill: AppColors.accentSoft,
            ink: AppColors.accent,
          ),
          title: change.title,
          detail: TextSpan(
            text: [
              l10n.agentChangeNewGoal,
              if (change.goal != null) _goal(l10n, change.goal!),
            ].join(' · '),
          ),
        );
      case PlanChangeKind.removeGoal:
        return AnswerRow(
          mark: const AnswerMark(
            icon: AppIcons.trash,
            fill: AppColors.danger,
            ink: AppColors.dangerInk,
          ),
          title: change.title,
          struck: true,
          detail: TextSpan(
            text: [
              l10n.agentChangeRemoveGoal,
              if (change.goal != null) _goal(l10n, change.goal!),
            ].join(' · '),
          ),
        );
      case PlanChangeKind.addTask ||
          PlanChangeKind.moveTask ||
          PlanChangeKind.addEvent ||
          PlanChangeKind.moveEvent ||
          PlanChangeKind.toBacklog:
        break;
    }

    final (fill, ink) = change.kind.fixed
        ? (AppColors.fixedFill, AppColors.fixedInk)
        : change.routine
        ? (AppColors.routineFill, AppColors.routineInk)
        : change.kind.adds
        ? (AppColors.accentSoft, AppColors.accent)
        : (AppColors.bg, AppColors.ink2);
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
    final before = change.before;
    // A move across days names both, so a wrong day shows before Aplicar.
    final at = change.at;
    final days = before != null && at != null && !_sameDay(before, at);
    String hour(DateTime at) =>
        days ? '${_weekday(l10n, at)} ${_hhmm(at)}' : _hhmm(at);

    return AnswerRow(
      mark: AnswerMark(
        icon: change.kind.adds ? AppIcons.plus : AppIcons.arrowRight,
        fill: fill,
        ink: ink,
      ),
      title: change.title,
      detail: TextSpan(
        children: [
          if (before != null && !change.kind.adds) ...[
            TextSpan(text: hour(before), style: struck),
            const TextSpan(text: ' → '),
            TextSpan(text: at == null ? l10n.stageBacklog : hour(at)),
          ] else if (at == null)
            TextSpan(text: l10n.stageBacklog)
          else
            TextSpan(text: '${_hhmm(at)}–${_hhmm(change.end!)}'),
          TextSpan(text: ' · $what'),
        ],
      ),
    );
  }

  /// "14:00 · concluída", or only [what] for a card with no hour.
  String _hourOr(AppLocalizations l10n, String what) {
    final at = change.at;
    return at == null ? what : '${_hhmm(at)} · $what';
  }
}

/// What a note adds, in full, as it will be written: the person reads their
/// own notes before Aplicar.
class _Added extends StatelessWidget {
  const _Added({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 2),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: '+ ',
              style: TextStyle(color: AppColors.accent),
            ),
            TextSpan(text: text),
          ],
        ),
        style: AppTypography.body,
      ),
    );
  }
}

/// The tasks that go along with an artifact: with it into the bin, or into
/// a new one.
class _Along extends StatelessWidget {
  const _Along({required this.titles, this.going = false});

  final List<String> titles;

  final bool going;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final title in titles)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: AppSpacing.s2),
                  decoration: BoxDecoration(
                    color: going ? AppColors.dangerInk : AppColors.ink3,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.ink2,
                      decoration: going ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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

    return AnswerRow(
      mark: const AnswerMark(icon: AppIcons.pushed),
      title: pushed.title,
      detail: TextSpan(
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

    return Padding(
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

/// "30/11".
String _ddmm(DateTime at) =>
    '${at.day.toString().padLeft(2, '0')}/'
    '${at.month.toString().padLeft(2, '0')}';

/// Whole reais as Entregas writes them: "R$ 4.900".
String _reais(int reais) {
  final digits = reais.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return 'R\$ ${reais < 0 ? '-' : ''}$grouped';
}

/// "R$ 8.000 por mês", "3 por semana".
String _goal(AppLocalizations l10n, PlanGoal goal) {
  final amount = goal.money ? _reais(goal.target) : '${goal.target}';
  return goal.monthly
      ? l10n.agentGoalPerMonth(amount)
      : l10n.agentGoalPerWeek(amount);
}

String _capitalised(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
