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
import 'package:lunna/plan/view/home_page.dart';
import 'package:lunna/plan/view/later_page.dart';
import 'package:timeline/timeline.dart';

/// Preview of #79 (UX and UI, part 1), on fakes. Not committed.
///
/// `?s=1` Plano with a task running; `?s=2` Plano on the break; `?s=3`
/// Plano before the working day opens; `?s=4` Para depois whole; `?s=5`
/// the calendar (Ver o dia) with a task running, play on what is next.
void main() {
  final scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;
  final today = DateTime.now();
  final at = DateTime(
    today.year,
    today.month,
    today.day,
    scene == 3 ? 6 : 10,
    scene == 3 ? 30 : 0,
  );
  final watch = Stopwatch()..start();
  withClock(
    Clock(() => at.add(watch.elapsed)),
    () => runApp(_PreviewApp(scene: scene)),
  );
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
      home: Builder(builder: (context) => _Fakes(scene: scene)),
    );
  }
}

class _Fakes extends StatefulWidget {
  const _Fakes({required this.scene});

  final int scene;

  @override
  State<_Fakes> createState() => _FakesState();
}

class _FakesState extends State<_Fakes> {
  late final DemoTimelineRepository _timeline = () {
    final repo = DemoTimelineRepository(
      context.l10n,
      resting: widget.scene != 1 && widget.scene != 5,
    );
    // On the break, nothing waits at this minute: the groceries keep an
    // hour of their own, at eleven.
    if (widget.scene == 2) {
      final now = clock.now();
      unawaited(
        repo.moveTask(
          'mercado',
          0,
          after: DateTime(now.year, now.month, now.day, 11),
        ),
      );
    }
    // On the calendar, a few more tasks queued after the groceries.
    if (widget.scene == 5) {
      unawaited(
        repo.createTask(
          title: 'Responder e-mails da Marina',
          minutes: 30,
          placement: const Placement.queue(99),
        ),
      );
      unawaited(
        repo.createTask(
          title: 'Revisar proposta do site',
          minutes: 45,
          placement: const Placement.queue(99),
        ),
      );
    }
    return repo;
  }();
  late final DemoArtifactsRepository _artifacts = _withOneTaskDelivery(
    DemoArtifactsRepository(context.l10n),
  );
  late final DemoAgentRepository _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
  );

  /// Adds a delivery begun whose one task is itself: the card that drew
  /// its name twice.
  static DemoArtifactsRepository _withOneTaskDelivery(
    DemoArtifactsRepository repo,
  ) {
    final now = clock.now();
    final d = repo.data;
    final kind = d.catalog.first.types.first;
    repo.data = ArtifactsData(
      schedule: d.schedule,
      catalog: d.catalog,
      goals: d.goals,
      topTypes: d.topTypes,
      artifacts: [
        ...d.artifacts,
        Artifact(
          id: 'cecilia',
          title: 'Revisar contrato da Cecília',
          minutes: 90,
          doneMinutes: 30,
          createdAt: DateTime(now.year, now.month),
          startedAt: DateTime(now.year, now.month, now.day - 2),
          deadline: DateTime(now.year, now.month, now.day + 4),
          type: kind,
          category: d.catalog.first,
          tasks: const [
            ArtifactTask(
              id: 'cecilia-1',
              title: 'Revisar contrato da Cecília',
              minutes: 60,
              place: TaskPlace.queue,
            ),
          ],
        ),
      ],
    );
    return repo;
  }

  @override
  Widget build(BuildContext context) {
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
        child: switch (widget.scene) {
          4 => const LaterPage(),
          5 => const _Day(),
          _ => const _Plano(),
        },
      ),
    );
  }
}

class _Plano extends StatelessWidget {
  const _Plano();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      body: HomePage(onSeeDay: () {}, onOpenLater: () {}),
      floatingActionButton: AskDock(
        fab: AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
      bottomNavigationBar: AppBottomBar(
        currentIndex: 0,
        onSelected: (_) {},
        items: [
          AppBottomBarItem(iconData: AppIcons.plan, label: l10n.shellPlanTab),
          AppBottomBarItem(iconData: AppIcons.goal, label: l10n.shellGoalsTab),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(iconData: AppIcons.back, onPressed: () {}),
        titleSpacing: 0,
        title: Text(l10n.dayPageTitle, style: AppTypography.title),
      ),
      body: TimelineList(onCardTap: (_) {}, onDeliveryTap: (_) {}),
      floatingActionButton: AskDock(
        fab: AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
    );
  }
}
