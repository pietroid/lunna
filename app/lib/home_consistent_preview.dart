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
import 'package:lunna/plan/view/plan_drag.dart';
import 'package:timeline/timeline.dart';

/// #87's mockup, Plano made consistent: `?s=<n>` picks the scene. Nothing
/// ships from here.
///
/// 1. The first read: each section's skeleton.
/// 2. Plano: Agora, Em seguida with Ver calendário, every card with an hour.
/// 3. Further down: tomorrow's tasks, + Adicionar, Pendentes, Para depois
///    whole with its own + Adicionar.
/// 4. Play on a 2 h task of Para depois: when, and how much.
/// 5. That task let go in Em seguida: how much goes there.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _PreviewApp()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 2;

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
    ..data = demoArtifacts(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
  );
  late final Future<void> _seeded = _seed(_timeline);

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
      child: FutureBuilder<void>(
        future: _seeded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(color: AppColors.bg);
          }
          return MultiBlocProvider(
            providers: [
              BlocProvider<TimelineBloc>(
                create: (context) {
                  final bloc = TimelineBloc(
                    repository: context.read<TimelineRepository>(),
                  );
                  // The first read never answers in scene 1.
                  if (_scene != 1) bloc.add(const TimelineRequested());
                  return bloc;
                },
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
          );
        },
      ),
    );
  }
}

/// A fuller day than the demo's, from 10:00: the queue between a standup,
/// lunch and a call, tomorrow's tasks at their hours, and Para depois.
Future<void> _seed(DemoTimelineRepository day) async {
  final now = clock.now();
  DateTime at(int days, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour, minute);
  await day.createTask(
    title: 'Responder e-mails da semana',
    minutes: 40,
    placement: const Placement.queue(99),
  );
  await day.createEvent(
    title: 'Almoço com a Bia',
    durationMinutes: 60,
    startTime: at(0, 12, 30),
  );
  await day.createTask(
    title: 'Notas fiscais de outubro',
    minutes: 60,
    placement: const Placement.queue(99),
  );
  await day.createEvent(
    title: 'Call com a Júlia',
    durationMinutes: 45,
    startTime: at(0, 15),
  );
  await day.createTask(
    title: 'Revisar orçamento do site',
    minutes: 30,
    placement: const Placement.queue(99),
  );
  await day.createTask(
    title: 'Gravar o vídeo do lançamento',
    minutes: 60,
    placement: Placement.at(at(1, 9, 40)),
  );
  await day.createTask(
    title: 'Enviar proposta da Moinho',
    minutes: 30,
    placement: Placement.at(at(1, 11)),
  );
  for (final (title, minutes) in const [
    ('Revisar contrato da Moinho', 120),
    ('Pesquisar fornecedores', 45),
    ('Trocar o plano do celular', 15),
  ]) {
    await day.createTask(title: title, minutes: minutes);
  }
}

class _Scene extends StatefulWidget {
  const _Scene();

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  final _scroll = ScrollController(initialScrollOffset: _scene == 3 ? 560 : 0);

  TimelineEvent? _contract(TimelineState day) => day.backlog
      .where((c) => c.title.startsWith('Revisar contrato'))
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    if (_scene == 4 || _scene == 5) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    final bloc = context.read<TimelineBloc>();
    final day = await bloc.stream.firstWhere(
      (s) => s.status == TimelineStatus.success && _contract(s) != null,
    );
    if (!mounted) return;
    final card = _contract(day)!;
    if (_scene == 4) {
      unawaited(playCard(context, card));
      return;
    }
    final items = PlanItems.of(
      day,
      context.read<ArtifactsCubit>().state.data,
      clock.now(),
    );
    final before = items.next.elementAtOrNull(1);
    unawaited(
      PlaceSheet.show(
        context,
        PlaceSheet(
          title: card.title,
          owed: card.workMinutes,
          at: slotHourOf(items, before),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomePage(
        onSeeDay: () {},
        onOpenLater: () {},
        controller: _scroll,
      ),
    );
  }
}
