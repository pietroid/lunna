import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/data/demo_repositories.dart';
import 'package:lunna/demo/demo_clock.dart';
import 'package:lunna/home/home.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/overview/overview.dart';
import 'package:lunna/panel/panel.dart';
import 'package:timeline/timeline.dart';

/// The Lunna home and Painel, drawn on the demo's fakes, one scene per `?s=`:
///
/// 1. Lunna, the top: the offer, Agora and what follows.
/// 2. Lunna, scrolled to the end: the main delivery and the goal.
/// 3. Painel › Tarefas on the calendar, as "Ver o dia" opens it.
/// 4. Painel › Entregas.
/// 5. Painel › Objetivos.
///
/// Nothing ships from here.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(const Clock()), () => runApp(const _Preview()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Fakes(),
    );
  }
}

/// The agent's offer, canned: an hour for the delivery most behind.
class _SuggestingAgent extends DemoAgentRepository {
  _SuggestingAgent(
    this.l10n, {
    required super.timeline,
    required super.artifacts,
  }) : super(l10n);

  final AppLocalizations l10n;

  @override
  Future<AgentSuggestion?> suggestion() async {
    final now = clock.now();
    return AgentSuggestion(
      text: l10n.demoSuggestionRenata,
      plan: AgentPlan(
        id: 'preview-renata',
        changes: [
          PlanChange(
            kind: PlanChangeKind.addTask,
            title: l10n.demoDeliveryRenata,
            minutes: 45,
            at: DateTime(now.year, now.month, now.day, 11, 10),
          ),
        ],
      ),
    );
  }
}

class _Fakes extends StatefulWidget {
  const _Fakes();

  @override
  State<_Fakes> createState() => _FakesState();
}

class _FakesState extends State<_Fakes> {
  late final _timeline = DemoTimelineRepository(context.l10n);
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = _SuggestingAgent(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
  );

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>.value(value: _timeline),
        RepositoryProvider<AgentRepository>.value(value: _agent),
        RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
        RepositoryProvider<OpenDayHours>(create: (_) => OpenDayHours(() {})),
        RepositoryProvider<AgentLinks>(
          create: (context) =>
              AgentLinks(openArtifact: (id) => openArtifact(context, id)),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineBloc>(
            create: (context) =>
                TimelineBloc(repository: context.read<TimelineRepository>())
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<TimelineModeCubit>(
            create: (_) => TimelineModeCubit()
              ..choose(
                _scene == 3 ? TimelineMode.calendar : TimelineMode.list,
              ),
          ),
          BlocProvider<AgentCubit>(
            create: (context) =>
                AgentCubit(repository: context.read<AgentRepository>()),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => VoiceCubit(recognizer: const DemoVoiceRecognizer()),
          ),
          BlocProvider<ArtifactsCubit>(
            create: (_) => ArtifactsCubit(
              repository: _artifacts,
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: _artifacts.data,
              ),
            ),
          ),
        ],
        child: const _Shell(),
      ),
    );
  }
}

/// The shell as `ShellPage` draws it, without the account, the reminders
/// and the analytics.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late int _index = _scene <= 2 ? 0 : 1;
  late PanelTab _panel = switch (_scene) {
    4 => PanelTab.deliveries,
    5 => PanelTab.goals,
    _ => PanelTab.tasks,
  };
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (_scene == 2) {
      // Once the day and the deliveries are in, the end of the page.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(PanelTab tab) {
    if (tab == PanelTab.calendar) {
      context.read<TimelineModeCubit>().choose(TimelineMode.calendar);
    }
    setState(() {
      _index = 1;
      _panel = tab == PanelTab.calendar ? PanelTab.tasks : tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deliveries = _index == 1 && _panel == PanelTab.deliveries;
    final goals = _index == 1 && _panel == PanelTab.goals;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          OverviewPage(onOpen: _open, firstName: 'Pietro', controller: _scroll),
          PanelPage(tab: _panel, onSelected: _open),
          const MenuPage(),
        ],
      ),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(
          tooltip: deliveries
              ? l10n.artifactsNew
              : goals
              ? l10n.goalsNew
              : l10n.shellWriteDown,
          onPressed: () {},
        ),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: (index) => setState(() => _index = index),
        items: [
          AppBottomBarItem(
            iconData: AppIcons.agent,
            label: l10n.appName(AppBrand.id),
          ),
          AppBottomBarItem(iconData: AppIcons.panel, label: l10n.shellPanelTab),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}
