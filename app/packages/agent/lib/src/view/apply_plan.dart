import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:agent/src/view/failure_note.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Applies [plan] and draws the day it leaves, which keeps the plan as the
/// one [UndoChip] offers to take back. Answers whether it went through.
///
/// The one place the agent's work reaches the day. The server makes the
/// changes; the answer is the whole timeline, as every write's is. The cards
/// it changed are drawn like any others.
Future<bool> applyAgentPlan(BuildContext context, AgentPlan plan) async {
  final l10n = context.l10n;
  final repository = context.read<AgentRepository>();
  final timeline = context.read<TimelineBloc>();
  final agent = context.read<AgentCubit>();
  final messenger = ScaffoldMessenger.of(context);

  agent.markPlan(plan.id, PlanStatus.applying);
  try {
    final day = await repository.apply(plan.id, days: timeline.state.days);
    timeline.add(TimelineReplaced(day, undoable: plan.id));
    agent.markPlan(plan.id, PlanStatus.applied);

    return true;
  } on AgentFailure catch (failure) {
    agent.markPlan(plan.id, PlanStatus.pending);
    messenger.showSnackBar(
      SnackBar(content: Text(agentFailureText(l10n, failure))),
    );

    return false;
  }
}

/// {@template undo_chip}
/// Takes the agent's last plan back, from the top of Tempo.
///
/// There while the plan can be undone exactly: until the user changes the
/// day by hand, another plan is applied, or the server no longer keeps it.
/// It does not time out on its own, so it never leaves before the user has
/// seen what the plan did.
/// {@endtemplate}
class UndoChip extends StatefulWidget {
  /// {@macro undo_chip}
  const UndoChip({super.key});

  @override
  State<UndoChip> createState() => _UndoChipState();
}

class _UndoChipState extends State<UndoChip> {
  bool _busy = false;

  Future<void> _undo(String planId) async {
    final l10n = context.l10n;
    final repository = context.read<AgentRepository>();
    final timeline = context.read<TimelineBloc>();
    final agent = context.read<AgentCubit>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      timeline.add(
        TimelineReplaced(
          await repository.undo(planId, days: timeline.state.days),
        ),
      );
      agent.markPlan(planId, PlanStatus.undone);
    } on AgentFailure catch (failure) {
      // Gone from the server (expired, or a restart): nothing left to undo,
      // so the day is drawn as it is, without the offer.
      timeline.add(TimelineReplaced(_dayOf(timeline.state)));
      messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? l10n.agentFailure)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planId = context.select<TimelineBloc, String?>(
      (bloc) => bloc.state.undoable,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: planId == null
          ? const SizedBox.shrink()
          : Material(
              key: const ValueKey('undo'),
              color: AppColors.fill,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _busy ? null : () => _undo(planId),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s3,
                    AppSpacing.s2,
                    AppSpacing.s4,
                    AppSpacing.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      else
                        const AppIcon(
                          iconData: AppIcons.undo,
                          size: 17,
                          color: AppColors.accent,
                        ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        context.l10n.agentUndo,
                        style: AppTypography.labelStrong.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The day on screen as it stands, to redraw it without the plan's id.
Timeline _dayOf(TimelineState state) => Timeline(
  cards: state.cards,
  tasks: state.tasks,
  backlog: state.backlog,
  workDay: state.workDay,
);
