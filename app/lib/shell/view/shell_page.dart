import 'dart:async';

import 'package:agent/agent.dart';
import 'package:analytics/analytics.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:cycle/cycle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/notifications/notifications.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/tempo/tempo.dart';
import 'package:timeline/timeline.dart';

/// {@template shell_page}
/// The app's three destinations, and the button that writes something down.
///
/// **Plano** is the home ([HomePage]): the agent's offer, what runs now and
/// what follows, the tasks under way (Pendentes) and the first of those
/// waiting (Para depois). **Objetivos** is the goals ([GoalsPage]).
/// **Menu** is the rest. The calendar (*Ver o dia*, [DayPage]) and the
/// whole of Para depois ([LaterPage]) are pages pushed over Plano.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// Every tab has the agent's bar at its foot ([AskDock]), in the same
/// place, and the + beside it. On Objetivos the + writes a goal; anywhere
/// else a task, into Para depois (from Menu it brings Plano forward first,
/// so the new task is on screen when the sheet closes).
///
/// The deliveries and goals are read again each time a tab comes to the
/// front, since the hours of their tasks on the day move with the day.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Plano, the home.
  static const _planIndex = 0;

  /// Objetivos, the goals.
  static const _goalsIndex = 1;

  /// Menu, where the working day's hours are set.
  static const _menuIndex = 2;

  int _index = _planIndex;

  /// Where the calendar is looking, which is where its + writes.
  final _aim = TimelineAim();

  /// What Agora's "Mudar horário" does: brings Menu forward.
  late final _openDayHours = OpenDayHours(() => _onSelected(_menuIndex));

  /// What a weekend day's rest row on the calendar does: that one day back
  /// to work, through the rhythm's cubit.
  late final _workOn = WorkOnDay(
    (day) => unawaited(context.read<CycleCubit>().workOn([day])),
  );

  @override
  void initState() {
    super.initState();
    unawaited(context.read<ArtifactsCubit>().load());
    unawaited(AnalyticsScope.of(context).screen(_screenName));
  }

  /// The name the screen in front is reported under: they are one route, so
  /// the router never sees them change.
  String get _screenName => switch (_index) {
    _goalsIndex => 'Objetivos',
    _menuIndex => 'Menu',
    _ => 'Plano',
  };

  void _onSelected(int index) {
    final before = _screenName;
    setState(() => _index = index);
    if (_screenName != before) {
      unawaited(AnalyticsScope.of(context).screen(_screenName));
    }
    if (_index != _menuIndex) {
      unawaited(context.read<ArtifactsCubit>().load());
    }
  }

  void _openLater(BuildContext context) {
    unawaited(AnalyticsScope.of(context).screen('Para depois'));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LaterPage()),
      ),
    );
  }

  void _seeDay(BuildContext context) {
    unawaited(AnalyticsScope.of(context).screen('Calendário'));
    unawaited(DayPage.open(context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineAim>.value(value: _aim),
        RepositoryProvider<OpenDayHours>.value(value: _openDayHours),
        RepositoryProvider<WorkOnDay>.value(value: _workOn),
        // What the agent's answers open (an artifact's page) and how its
        // previews draw a goal or a delivery.
        RepositoryProvider<AgentLinks>.value(
          value: AgentLinks(
            openArtifact: (id) => openArtifact(context, id),
            preview: drawAgentPreview,
          ),
        ),
      ],
      child: Builder(
        builder: (context) => RemindersListener(
          child: Scaffold(
            // The bar fogs whatever runs under it, so the body runs under it.
            extendBody: true,
            body: IndexedStack(
              index: _index,
              children: [
                HomePage(
                  shown: _index == _planIndex,
                  onSeeDay: () => _seeDay(context),
                  onOpenLater: () => _openLater(context),
                ),
                const GoalsPage(),
                const MenuPage(),
              ],
            ),
            // One button for the three tabs: the composer's +, which reads
            // a task, an event, a goal or a change to the day from the words.
            floatingActionButton: const AskDock(),
            floatingActionButtonLocation: AskDock.location,
            floatingActionButtonAnimator: AskDock.animator,
            bottomNavigationBar: AppBottomBar(
              currentIndex: _index,
              onSelected: _onSelected,
              items: [
                AppBottomBarItem(
                  iconData: AppIcons.plan,
                  label: l10n.shellPlanTab,
                ),
                AppBottomBarItem(
                  iconData: AppIcons.goal,
                  label: l10n.shellGoalsTab,
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
}
