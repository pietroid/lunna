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
import 'package:timeline/timeline.dart';

/// Prints of the Objetivos tab, against fixed data. `?s=<n>` picks the
/// scene:
///
/// 1. Objetivos with no goal yet.
/// 2. The goal sheet, open on "Próximo mês".
/// 3. Objetivos with a goal under way, the next one and two past.
/// 4. The delivery sheet: the value, prefilled by the kind, and the goal
///    it counts for.
/// 5. A delivery's page, with its value.
///
/// Nothing ships from here.
void main() {
  final scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 3;
  withClock(Clock.fixed(DateTime(2026, 10, 28, 10)), () {
    runApp(_PreviewApp(scene: scene));
  });
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.scene});

  final int scene;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Scene(scene: scene),
    );
  }
}

/// The goals of scene 3: two months gone by, this one, and the next.
List<Goal> _goals() => [
  Goal(
    id: 'ago',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 8000,
    done: 6900,
    start: DateTime(2026, 8),
    end: DateTime(2026, 9),
  ),
  Goal(
    id: 'set',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 8000,
    done: 8650,
    start: DateTime(2026, 9),
    end: DateTime(2026, 10),
  ),
  Goal(
    id: 'nov',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 10000,
    done: 2850,
    start: DateTime(2026, 10),
    end: DateTime(2026, 12),
  ),
  Goal(
    id: 'dez',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 12000,
    start: DateTime(2026, 12),
    end: DateTime(2027),
  ),
];

class _Scene extends StatefulWidget {
  const _Scene({required this.scene});

  final int scene;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  late final _timeline = DemoTimelineRepository(context.l10n);
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
  );

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final data = _artifacts.data;
    _artifacts.data = ArtifactsData(
      artifacts: data.artifacts,
      catalog: data.catalog,
      goals: switch (scene) {
        1 || 2 => const [],
        _ => _goals(),
      },
      schedule: data.schedule,
      topTypes: data.topTypes,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>.value(value: _timeline),
        RepositoryProvider<AgentRepository>.value(value: _agent),
        RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineBloc>(
            create: (context) =>
                TimelineBloc(repository: context.read<TimelineRepository>())
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<TimelineModeCubit>(create: (_) => TimelineModeCubit()),
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
        // Pages and sheets are pushed under the providers, as in the demo.
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => _Shell(scene: scene),
          ),
        ),
      ),
    );
  }
}

/// The shell as the app draws it, with the four tabs.
class _Shell extends StatefulWidget {
  const _Shell({required this.scene});

  final int scene;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final int _index = widget.scene >= 4 ? 1 : 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    final data = context.read<ArtifactsCubit>().state.data!;
    final shelf = data.catalog.first;
    switch (widget.scene) {
      case 2:
        unawaited(showGoalSheet(context, amount: 10000));
      case 4:
        unawaited(
          showArtifactSheet(
            context,
            initialCategory: shelf,
            initialType: shelf.types.first,
            initialName: '${shelf.types.first.name} · Camila',
            initialDeadline: DateTime(2026, 11, 6),
          ),
        );
      case 5:
        unawaited(openArtifact(context, 'renata', tab: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [SizedBox(), ArtifactsPage(), GoalsPage()],
      ),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(
          tooltip: _index == 2 ? l10n.goalsNew : l10n.artifactsNew,
          onPressed: () => unawaited(
            _index == 2 ? showGoalSheet(context) : showArtifactSheet(context),
          ),
        ),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: (_) {},
        items: [
          AppBottomBarItem(
            iconData: AppIcons.time,
            label: l10n.shellTimelineTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.artifacts,
            label: l10n.shellArtifactsTab,
          ),
          AppBottomBarItem(iconData: AppIcons.goal, label: l10n.shellGoalsTab),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}
