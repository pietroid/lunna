import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Applies [plan], draws the day it leaves, and offers to undo it.
///
/// The one place the agent's work reaches the day. The server makes the
/// changes; the answer is the whole timeline, as every write's is, along with
/// the cards it changed, which the list then marks. Answers whether it went
/// through.
Future<bool> applyAgentPlan(BuildContext context, AgentPlan plan) async {
  final l10n = context.l10n;
  final repository = context.read<AgentRepository>();
  final timeline = context.read<TimelineBloc>();
  final agent = context.read<AgentCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final days = timeline.state.days;

  agent.markPlan(plan.id, PlanStatus.applying);
  try {
    final applied = await repository.apply(plan.id, days: days);
    timeline.add(
      TimelineReplaced(applied.timeline, touched: applied.touched),
    );
    agent.markPlan(plan.id, PlanStatus.applied);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const AppIcon(iconData: AppIcons.agent, size: AppSpacing.s5),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(l10n.agentAppliedToast(plan.changes.length)),
              ),
            ],
          ),
          action: SnackBarAction(
            label: l10n.agentUndo,
            textColor: AppColors.accent,
            onPressed: () async {
              try {
                timeline.add(
                  TimelineReplaced(await repository.undo(plan.id, days: days)),
                );
                agent.markPlan(plan.id, PlanStatus.pending);
              } on AgentFailure catch (failure) {
                messenger.showSnackBar(
                  SnackBar(content: Text(failure.message ?? l10n.agentFailure)),
                );
              }
            },
          ),
        ),
      );

    return true;
  } on AgentFailure catch (failure) {
    agent.markPlan(plan.id, PlanStatus.pending);
    messenger.showSnackBar(
      SnackBar(content: Text(failure.message ?? l10n.agentFailure)),
    );

    return false;
  }
}
