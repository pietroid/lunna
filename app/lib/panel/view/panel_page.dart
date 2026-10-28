import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/home.dart';

/// A level of Painel, and the one way in that is not a level: Tarefas
/// opened on the calendar.
enum PanelTab {
  /// Tarefas, the day, drawn whichever way it was left.
  tasks,

  /// Tarefas on the calendar: what the Lunna tab's "Ver o dia" opens.
  calendar,

  /// Entregas.
  deliveries,

  /// Objetivos.
  goals;

  /// The word at the top of Painel that is lit for it.
  int get level => switch (this) {
    PanelTab.tasks || PanelTab.calendar => 0,
    PanelTab.deliveries => 1,
    PanelTab.goals => 2,
  };

  /// The tab for the word at [level].
  static PanelTab at(int level) =>
      const [PanelTab.tasks, PanelTab.deliveries, PanelTab.goals][level];
}

/// {@template panel_page}
/// Painel: the three levels of what she manages, one over the other, in one
/// tab. Tarefas is the day (Lista or Calendário), Entregas the deliveries,
/// Objetivos the goals: the screens they always were, under one heading.
///
/// The heading is the tabs ([AppTitleTabs]): picking a level is picking
/// what the screen is about, so it reads as a title, and the switch between
/// Lista and Calendário under Tarefas stays the one control that looks like
/// a control. Every level is kept alive behind an [IndexedStack], as the
/// app's tabs are, so each list is where it was left.
/// {@endtemplate}
class PanelPage extends StatelessWidget {
  /// {@macro panel_page}
  const PanelPage({required this.tab, required this.onSelected, super.key});

  /// The level in front.
  final PanelTab tab;

  /// Called with the level a word was tapped for.
  final ValueChanged<PanelTab> onSelected;

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
                    l10n.panelTasks,
                    l10n.shellArtifactsTab,
                    l10n.shellGoalsTab,
                  ],
                  selected: tab.level,
                  onSelected: (level) => onSelected(PanelTab.at(level)),
                  // Entregas' search, which its own heading carried.
                  trailing: tab == PanelTab.deliveries
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
                    HomePage(),
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
