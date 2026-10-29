import 'dart:async';

import 'package:agent/agent.dart';
import 'package:analytics/analytics.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/feed/feed.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/notifications/notifications.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/tempo/tempo.dart';
import 'package:timeline/timeline.dart';

/// {@template shell_page}
/// The app's three destinations, and the button that writes something down.
///
/// **Feed** is the home ([FeedPage]): the agent's offer, what runs now
/// and what follows, the main delivery and the goal. **Plano** holds the
/// three levels of what the person manages ([PlanPage]): Tarefas, Entregas,
/// Objetivos. **Menu** is the rest.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// Every tab has the agent's bar at its foot ([AskDock]), in the same
/// place, and the + beside it. The + writes down whatever is in front: on
/// Plano's Entregas a delivery, on its Objetivos a goal, anywhere else
/// something on the timeline, where Tempo is looking; from Menu it brings
/// Tarefas forward first, so the new block is on screen when the sheet
/// closes.
///
/// Entregas and Objetivos are read again each time they come to the front,
/// since the hours of their tasks on the day move with the day.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Feed, the home.
  static const _feedIndex = 0;

  /// Plano: Tarefas, Entregas, Objetivos.
  static const _planIndex = 1;

  /// Menu, where the working day's hours are set.
  static const _menuIndex = 2;

  int _index = _feedIndex;

  /// The level of Plano in front.
  PlanTab _plan = PlanTab.tasks;

  /// Where Tempo is looking, which is where the button writes.
  final _aim = TimelineAim();

  /// Lista or Calendário, kept here so the Feed tab can open the calendar.
  final _mode = TimelineModeCubit();

  /// What Agora's "Mudar horário" does: brings Menu forward.
  late final _openDayHours = OpenDayHours(() => _onSelected(_menuIndex));

  @override
  void initState() {
    super.initState();
    unawaited(_mode.restore());
    unawaited(context.read<ArtifactsCubit>().load());
    unawaited(AnalyticsScope.of(context).screen(_screenName));
  }

  @override
  void dispose() {
    unawaited(_mode.close());
    super.dispose();
  }

  /// The name the screen in front is reported under: they are one route, so
  /// the router never sees them change.
  String get _screenName => switch (_index) {
    _feedIndex => 'Feed',
    _menuIndex => 'Menu',
    _ => switch (_plan) {
      PlanTab.deliveries => 'Entregas',
      PlanTab.goals => 'Objetivos',
      _ => 'Tempo',
    },
  };

  void _show(int index, [PlanTab? plan]) {
    final before = _screenName;
    setState(() {
      _index = index;
      if (plan != null) _plan = plan;
    });
    if (_screenName != before) {
      unawaited(AnalyticsScope.of(context).screen(_screenName));
    }
    if (_index == _feedIndex || (_index == _planIndex && _plan.level > 0)) {
      unawaited(context.read<ArtifactsCubit>().load());
    }
  }

  void _onSelected(int index) => _show(index);

  /// A level of Plano, from its heading or from the Feed tab.
  void _openPlan(PlanTab tab) {
    if (tab == PlanTab.calendar) {
      _mode.choose(TimelineMode.calendar);
    }
    _show(_planIndex, tab == PlanTab.calendar ? PlanTab.tasks : tab);
  }

  Future<void> _onFabPressed() async {
    if (_index == _planIndex && _plan == PlanTab.deliveries) {
      await showArtifactSheet(context);
      return;
    }
    if (_index == _planIndex && _plan == PlanTab.goals) {
      await showGoalSheet(context);
      return;
    }

    if (_index == _menuIndex) _show(_planIndex, PlanTab.tasks);
    await writeDownOnTimeline(
      context,
      placement: _aim.value ?? const Placement.backlog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final deliveries = _index == _planIndex && _plan == PlanTab.deliveries;
    final goals = _index == _planIndex && _plan == PlanTab.goals;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineAim>.value(value: _aim),
        RepositoryProvider<OpenDayHours>.value(value: _openDayHours),
        // What the agent's answers open: an artifact's page, from Tempo.
        RepositoryProvider<AgentLinks>.value(
          value: AgentLinks(openArtifact: (id) => openArtifact(context, id)),
        ),
      ],
      child: BlocProvider<TimelineModeCubit>.value(
        value: _mode,
        child: RemindersListener(
          child: Scaffold(
            // The bar fogs whatever runs under it, so the body runs under it.
            extendBody: true,
            body: IndexedStack(
              index: _index,
              children: [
                FeedPage(
                  shown: _index == _feedIndex,
                  firstName: firstName,
                  onOpen: _openPlan,
                  onProfile: _profileMenu,
                ),
                PlanPage(tab: _plan, onSelected: _openPlan),
                const MenuPage(),
              ],
            ),
            // One dock for the three tabs: the bar and a recording on it stay
            // as they are when the tab changes, and only the + beside it
            // changes what it writes.
            floatingActionButton: AskDock(
              // The conversation is about the day Tempo is showing.
              day: () => _aim.value?.at,
              fab: AppFab(
                tooltip: deliveries
                    ? l10n.artifactsNew
                    : goals
                    ? l10n.goalsNew
                    : l10n.shellWriteDown,
                onPressed: () => unawaited(_onFabPressed()),
              ),
            ),
            floatingActionButtonLocation: AskDock.location,
            floatingActionButtonAnimator: AskDock.animator,
            bottomNavigationBar: AppBottomBar(
              currentIndex: _index,
              onSelected: _onSelected,
              items: [
                AppBottomBarItem(
                  iconData: AppIcons.agent,
                  label: l10n.shellFeedTab,
                ),
                AppBottomBarItem(
                  iconData: AppIcons.plan,
                  label: l10n.shellPlanTab,
                ),
                AppBottomBarItem(
                  iconData: AppIcons.menu,
                  label: l10n.shellMenuTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The account menu behind the greeting: the routines, and signing out.
  List<PopupMenuEntry<void>> _profileMenu(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () => unawaited(context.push<void>('/rotina')),
      child: Row(
        children: [
          const AppIcon(iconData: AppIcons.repeat, size: AppSpacing.s5),
          const SizedBox(width: AppSpacing.s3),
          Text(context.l10n.homeRoutines),
        ],
      ),
    ),
    PopupMenuItem<void>(
      onTap: () => context.read<AppBloc>().add(const AppLogoutRequested()),
      child: Row(
        children: [
          const AppIcon(iconData: AppIcons.logout, size: AppSpacing.s5),
          const SizedBox(width: AppSpacing.s3),
          Text(context.l10n.homeSignOut),
        ],
      ),
    ),
  ];
}
