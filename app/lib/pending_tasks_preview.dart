import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/plan/plan.dart';
import 'package:timeline/timeline.dart';

/// Pendentes, part 3's mockup: `?s=<n>` picks the scene. Nothing ships from
/// here.
///
/// 1. Plano at Pendentes: the day in the corner, −1d +1d ✓, urgent.
/// 2. Play on a task with no tasks, 2h30 owed: how much now?
/// 3. Play on a task with tasks, its next one 1h30: begin it?
/// 4. A pending card carried over Agora.
/// 5. Let go there while something runs: what of the running one?
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _PreviewApp()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Repositories(),
    );
  }
}

class _Repositories extends StatefulWidget {
  const _Repositories();

  @override
  State<_Repositories> createState() => _RepositoriesState();
}

class _RepositoriesState extends State<_Repositories> {
  late final _timeline = DemoTimelineRepository(context.l10n);
  late final _artifacts = DemoArtifactsRepository(context.l10n)
    ..data = _pending(_artifactsBase());
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
  );

  ArtifactsData _artifactsBase() => demoArtifacts(context.l10n);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>.value(value: _timeline),
        RepositoryProvider<AgentRepository>.value(value: _agent),
        RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
        RepositoryProvider<AgentLinks>.value(
          value: const AgentLinks(preview: drawAgentPreview),
        ),
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
        child: const _Scene(),
      ),
    );
  }
}

/// The pending tasks the scenes draw, counted from today at 10:00.
ArtifactsData _pending(ArtifactsData base) {
  final now = clock.now();
  DateTime inDays(int days) => DateTime(now.year, now.month, now.day + days);
  ArtifactTask task(String id, String title, int minutes, TaskPlace place) =>
      ArtifactTask(id: id, title: title, minutes: minutes, place: place);

  return ArtifactsData(
    schedule: base.schedule,
    catalog: base.catalog,
    goals: base.goals,
    topTypes: base.topTypes,
    artifacts: [
      Artifact(
        id: 'relatorio',
        title: 'Relatório trimestral',
        minutes: 240,
        doneMinutes: 90,
        createdAt: inDays(-10),
        startedAt: inDays(-6),
        deadline: inDays(-1),
      ),
      Artifact(
        id: 'proposta',
        title: 'Proposta para a Moinho',
        minutes: 180,
        doneMinutes: 30,
        createdAt: inDays(-3),
        startedAt: inDays(-1),
        deadline: inDays(2),
        timeGone: 0.35,
      ),
      Artifact(
        id: 'video',
        title: 'Vídeo do lançamento',
        // Its tasks add up to more than the 5 h it was written down with.
        minutes: 375,
        doneMinutes: 45,
        createdAt: inDays(-4),
        startedAt: inDays(-2),
        deadline: inDays(9),
        timeGone: 0.2,
        tasks: [
          task('pauta', 'Pauta', 45, TaskPlace.done),
          task('roteiro', 'Roteiro do vídeo', 90, TaskPlace.queue),
          task('gravacao', 'Gravação', 120, TaskPlace.backlog),
          task('edicao', 'Edição', 120, TaskPlace.backlog),
        ],
      ),
      Artifact(
        id: 'mapa',
        title: 'Mapa astral · Júlia',
        minutes: 180,
        doneMinutes: 120,
        createdAt: inDays(-5),
        startedAt: inDays(-3),
        deadline: inDays(0),
        timeGone: 0.8,
      ),
      Artifact(
        id: 'site',
        title: 'Site da Casa Lume',
        minutes: 600,
        createdAt: inDays(-1),
        deadline: inDays(20),
      ),
    ],
  );
}

class _Scene extends StatefulWidget {
  const _Scene();

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  // Scrolled past the offer, so Agora and Pendentes share the screen.
  final _scroll = ScrollController(
    initialScrollOffset: _scene == 4 ? 20 : 150,
  );

  @override
  void initState() {
    super.initState();
    if (_scene == 2 || _scene == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final data = context.read<ArtifactsCubit>().state.data!;
        final id = _scene == 2 ? 'proposta' : 'video';
        unawaited(
          PlaySheet.show(
            context,
            artifact: data.artifacts.firstWhere((a) => a.id == id),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final data = context.watch<ArtifactsCubit>().state.data!;
    return Scaffold(
      body: Stack(
        children: [
          HomePage(
            onSeeDay: () {},
            onOpenLater: () {},
            carrying: _scene == 4 ? 'mapa' : null,
            controller: _scroll,
          ),
          if (_scene == 4)
            Positioned(
              left: AppSpacing.s5 + 6,
              right: AppSpacing.s5 - 6,
              top: 138,
              child: Transform.rotate(
                angle: -0.02,
                child: Material(
                  elevation: 12,
                  shadowColor: AppColors.shadow,
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                  child: PendingCard(
                    artifact: data.artifacts.firstWhere(
                      (a) => a.id == 'mapa',
                    ),
                    now: now,
                  ),
                ),
              ),
            ),
          if (_scene == 5)
            GuardSheet(
              guard: StartNowGuard(
                taskId: 'mapa',
                index: 0,
                currentId: 'lunna',
                currentTitle: context.l10n.demoBuilding(AppBrand.id),
                currentStart: now.subtract(const Duration(minutes: 12)),
                currentEnd: now.add(const Duration(minutes: 33)),
              ),
              busy: false,
            ),
        ],
      ),
    );
  }
}
