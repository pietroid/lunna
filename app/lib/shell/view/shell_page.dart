import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/home.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template shell_page}
/// The app's three destinations, and the button that writes something down.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// The [AppFab] writes down whatever the tab in front is about. On Entregas
/// that is a delivery. Anywhere else it is something on the timeline, on the
/// day Tempo is showing: at the first free hour in sight on the calendar, at
/// the end of the day at the top of the list; from Menu it brings Tempo
/// forward first, so the new block is on screen when the sheet closes.
///
/// Entregas is read again each time it comes to the front, since the hours
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

  /// Entregas.
  static const _artifactsIndex = 1;

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
    unawaited(context.read<ArtifactsCubit>().load());
  }

  void _onSelected(int index) {
    // A recording started on Tempo's bar is drawn only there; leaving Tempo
    // drops it rather than keep listening out of sight.
    if (index != _timelineIndex) {
      unawaited(context.read<VoiceCubit>().cancel());
    }
    if (index == _artifactsIndex) {
      unawaited(context.read<ArtifactsCubit>().load());
    }
    setState(() => _index = index);
  }

  Future<void> _onFabPressed() async {
    if (_index == _artifactsIndex) {
      await showArtifactSheet(context);
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
        // What the agent's answers open: an artifact's page, from Tempo.
        RepositoryProvider<AgentLinks>.value(
          value: AgentLinks(openArtifact: (id) => openArtifact(context, id)),
        ),
      ],
      child: RemindersListener(
        child: Scaffold(
          // The bar fogs whatever runs under it, so the body runs under it.
          extendBody: true,
          body: IndexedStack(
            index: _index,
            children: const [HomePage(), ArtifactsPage(), MenuPage()],
          ),
          floatingActionButton: _index == _timelineIndex
              ? AskDock(
                  // The conversation is about the day Tempo is showing.
                  day: () => _aim.value?.at,
                  fab: AppFab(
                    tooltip: l10n.shellWriteDown,
                    onPressed: () => unawaited(_onFabPressed()),
                  ),
                )
              : AppFab(
                  tooltip: _index == _artifactsIndex
                      ? l10n.artifactsNew
                      : l10n.shellWriteDown,
                  onPressed: () => unawaited(_onFabPressed()),
                ),
          // On Tempo the bar and the + are one row, centred on the column.
          floatingActionButtonLocation: _index == _timelineIndex
              ? FloatingActionButtonLocation.centerFloat
              : AppFab.location,
          // The + is at the same place on every tab, so changing tabs
          // swaps what is drawn and moves nothing: no scaling out and in,
          // no slide between the two locations.
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          bottomNavigationBar: AppBottomBar(
            currentIndex: _index,
            onSelected: _onSelected,
            items: [
              AppBottomBarItem(
                iconData: AppIcons.time,
                label: l10n.shellTimelineTab,
              ),
              AppBottomBarItem(
                iconData: AppIcons.artifacts,
                label: l10n.shellArtifactsTab,
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
