import 'dart:async';
import 'dart:math' as math;

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/home.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/notifications/notifications.dart';
import 'package:projects/projects.dart';
import 'package:timeline/timeline.dart';

/// {@template shell_page}
/// The app's three destinations, and the button that writes something down.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// The [AppFab] writes down whatever the tab in front is about. On Projetos
/// that is a project. Anywhere else it is something on the timeline, on the
/// day Tempo is showing: at the first free hour in sight on the calendar, at
/// the end of the day at the top of the list; from Menu it brings Tempo
/// forward first, so the new block is on screen when the sheet closes.
///
/// Projetos is read again each time it comes to the front, since the hours
/// of its tasks on the day move with the day.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Tempo, the timeline.
  static const _timelineIndex = 0;

  /// Projetos.
  static const _projectsIndex = 1;

  /// Menu, where the working day's hours are set.
  static const _menuIndex = 2;

  int _index = _timelineIndex;

  /// Where Tempo is looking, which is where the button writes.
  final _aim = TimelineAim();

  /// What Agora's "Mudar horário" does: brings Menu forward.
  late final _openDayHours = OpenDayHours(() => _onSelected(_menuIndex));

  @override
  void initState() {
    super.initState();
    unawaited(context.read<ProjectsCubit>().load());
  }

  void _onSelected(int index) {
    if (index == _projectsIndex) {
      unawaited(context.read<ProjectsCubit>().load());
    }
    setState(() => _index = index);
  }

  Future<void> _onFabPressed() async {
    if (_index == _projectsIndex) {
      final cubit = context.read<ProjectsCubit>();
      final draft = await showProjectSheet(context);
      if (draft == null) return;
      await cubit.create(draft.title, deadline: draft.deadline);
      return;
    }

    if (_index != _timelineIndex) setState(() => _index = _timelineIndex);
    await writeDownOnTimeline(
      context,
      placement: _aim.value ?? const Placement.backlog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineAim>.value(value: _aim),
        RepositoryProvider<OpenDayHours>.value(value: _openDayHours),
      ],
      child: RemindersListener(
        child: Scaffold(
          // The bar fogs whatever runs under it, so the body runs under it.
          extendBody: true,
          body: IndexedStack(
            index: _index,
            children: const [HomePage(), ProjectsPage(), MenuPage()],
          ),
          floatingActionButton: _index == _timelineIndex
              ? _AskAndWrite(
                  // The conversation is about the day Tempo is showing.
                  day: () => _aim.value?.at,
                  fab: AppFab(
                    tooltip: l10n.shellWriteDown,
                    onPressed: () => unawaited(_onFabPressed()),
                  ),
                )
              : AppFab(
                  tooltip: _index == _projectsIndex
                      ? l10n.projectsNew
                      : l10n.shellWriteDown,
                  onPressed: () => unawaited(_onFabPressed()),
                ),
          floatingActionButtonLocation: AppFab.location,
          bottomNavigationBar: AppBottomBar(
            currentIndex: _index,
            onSelected: _onSelected,
            items: [
              AppBottomBarItem(
                iconData: AppIcons.time,
                label: l10n.shellTimelineTab,
              ),
              AppBottomBarItem(
                iconData: AppIcons.things,
                label: l10n.shellProjectsTab,
              ),
              AppBottomBarItem(
                iconData: AppIcons.menu,
                label: l10n.shellMenuTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The agent's bar and the +, side by side, on Tempo.
///
/// The + still writes something down in one tap; the bar beside it is
/// where a conversation starts. Both float where the + always did, across
/// the column the content is drawn in.
class _AskAndWrite extends StatelessWidget {
  const _AskAndWrite({required this.day, required this.fab});

  final DateTime? Function() day;

  final Widget fab;

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      MediaQuery.sizeOf(context).width,
      AppSpacing.maxContentWidth,
    );

    return SizedBox(
      width: width - 2 * kFloatingActionButtonMargin,
      child: Row(
        children: [
          Expanded(child: AskBar(day: day)),
          const SizedBox(width: AppSpacing.s3),
          fab,
        ],
      ),
    );
  }
}
