import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/tempo/tempo.dart';

/// A level of Plano, and the one way in that is not a level: Tarefas
/// opened on the calendar.
enum PlanTab {
  /// Tarefas, the day, drawn whichever way it was left.
  tasks,

  /// Tarefas on the calendar: what the Feed tab's "Ver o dia" opens.
  calendar,

  /// Entregas.
  deliveries,

  /// Objetivos.
  goals;

  /// The word at the top of Plano that is lit for it.
  int get level => switch (this) {
    PlanTab.tasks || PlanTab.calendar => 0,
    PlanTab.deliveries => 1,
    PlanTab.goals => 2,
  };

  /// The tab for the word at [level].
  static PlanTab at(int level) =>
      const [PlanTab.tasks, PlanTab.deliveries, PlanTab.goals][level];
}

/// {@template plan_page}
/// Plano: the three levels of what the person manages, one over the other,
/// in one tab. Tarefas is the day (Lista or Calendário), Entregas the
/// deliveries, Objetivos the goals: the screens they always were, under one
/// heading.
///
/// The heading is the tabs ([AppTitleTabs]): picking a level is picking
/// what the screen is about, so it reads as a title, and the switch between
/// Lista and Calendário under Tarefas stays the one control that looks like
/// a control. Every level is kept alive behind an [IndexedStack], as the
/// app's tabs are, so each list is where it was left.
/// {@endtemplate}
class PlanPage extends StatelessWidget {
  /// {@macro plan_page}
  const PlanPage({required this.tab, required this.onSelected, super.key});

  /// The level in front.
  final PlanTab tab;

  /// Called with the level a word was tapped for.
  final ValueChanged<PlanTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s5,
                  AppSpacing.s4,
                  AppSpacing.s3,
                  AppSpacing.s3,
                ),
                child: AppTitleTabs(
                  labels: [
                    l10n.planTasks,
                    l10n.shellArtifactsTab,
                    l10n.shellGoalsTab,
                  ],
                  selected: tab.level,
                  onSelected: (level) => onSelected(PlanTab.at(level)),
                  // Entregas' search, which its own heading carried.
                  trailing: tab == PlanTab.deliveries
                      ? IconButton(
                          tooltip: l10n.artifactsSearch,
                          onPressed: () => unawaited(openAllArtifacts(context)),
                          icon: const AppIcon(
                            iconData: AppIcons.search,
                            color: AppColors.ink2,
                          ),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: tab.level,
                  children: const [
                    TempoPage(),
                    ArtifactsPage(titled: false),
                    GoalsPage(titled: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
