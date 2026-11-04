import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:timeline/timeline.dart';

/// {@template later_page}
/// Para depois, whole: every task not begun, the loose ones and those with
/// tasks of their own, in one list ([PlanItems.later]), each with its play
/// button. Plano draws the first four of it.
///
/// A page of its own over the tabs, so it is handed nothing: the day and
/// the deliveries are the app's own blocs. The agent's bar floats at its
/// foot, as on every page.
/// {@endtemplate}
class LaterPage extends StatelessWidget {
  /// {@macro later_page}
  const LaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = context.watch<TimelineBloc>().state;
    final deliveries = context.watch<ArtifactsCubit>().state.data;
    final now = clock.now();
    final later = PlanItems.of(day, deliveries, now).later;
    final guard = day.guard;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(l10n.stageBacklog, style: AppTypography.title),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s5,
                    AppSpacing.s2,
                    AppSpacing.s5,
                    kNotesDockClearance,
                  ),
                  children: [
                    if (later.isEmpty)
                      Text(
                        l10n.homeLaterEmpty,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                      ),
                    for (final item in later)
                      Padding(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.only(bottom: kQueueGap),
                        child: LaterCard(item: item, now: now),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (guard != null) GuardSheet(guard: guard, busy: day.guardBusy),
        ],
      ),
      // The composer's +, as on every screen.
      floatingActionButton: const AskDock(),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
    );
  }
}
