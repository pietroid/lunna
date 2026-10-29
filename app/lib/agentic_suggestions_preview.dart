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
import 'package:lunna/feed/feed.dart';
import 'package:timeline/timeline.dart';

/// The agentic suggestion, on fakes. `?s=1` a new person's Feed: the
/// welcome. `?s=2` the conversation after tapping R$ 5.000 on it: the turn
/// in three parts, the goal drawn as Objetivos draws it. `?s=3` Feed three
/// hours later: the next turn (the deliveries that reach the goal), header,
/// preview, actions. `?s=4` Feed later on: the routine and the working day.
/// Nothing ships from here.
/// Saturday morning, the day the golden scenario starts.
void main() => withClock(
  Clock.fixed(DateTime(2026, 10, 31, 10)),
  () => runApp(const _App()),
);

final String _scene = Uri.base.queryParameters['s'] ?? '1';

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.current,
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const _Feed(),
  );
}

final DateTime _monthStart = DateTime(2026, 10, 31);
final DateTime _monthEnd = DateTime(2026, 12);

/// What the server would send for each scene.
AgentSuggestion _suggestion(String scene) => switch (scene) {
  '1' || '2' => AgentSuggestion(
    id: 'welcome',
    text: '',
    focus: SuggestionFocus.goal,
    validUntil: DateTime(2100),
    welcome: true,
  ),
  '3' => _turn(
    'Com essas duas entregas você chega a R\$ 4.200 dos R\$ 5.000. '
    'Anoto as duas?',
    PreviewBlock(
      items: [
        GoalPreview(
          target: 5000,
          queued: 4200,
          queuedCount: 2,
          start: _monthStart,
          end: _monthEnd,
        ),
        ArtifactPreview(
          title: 'Ensaio de gestante',
          minutes: 240,
          deadline: DateTime(2026, 11, 14),
          value: 1800,
        ),
        ArtifactPreview(
          title: 'Álbum da Marina',
          minutes: 360,
          deadline: DateTime(2026, 11, 25),
          value: 2400,
        ),
      ],
      applies: 'Aplicar anota as duas entregas.',
    ),
  ),
  _ => _turn(
    'As entregas do mês já têm tarefas. Que tal uma manhã de rotina antes '
    'do trabalho, e o dia indo até as 19:00?',
    const PreviewBlock(
      items: [
        RoutinePreview(
          title: 'Manhã',
          startMinute: 7 * 60,
          minutes: 60,
          days: RoutineDays.daily,
          checklist: ['Café', 'Meditar 10 minutos', 'Louça'],
        ),
        RoutinePreview(
          title: 'Edição',
          startMinute: 9 * 60,
          minutes: 180,
          days: RoutineDays.weekdays,
        ),
      ],
      applies: 'Aplicar anota as duas rotinas e o seu dia das 07:00 às 19:00.',
    ),
  ),
};

AgentSuggestion _turn(String text, PreviewBlock preview) {
  const plan = AgentPlan(id: 'turn', changes: []);
  return AgentSuggestion(
    id: 'turn',
    text: text,
    focus: SuggestionFocus.delivery,
    validUntil: DateTime(2026, 11, 1, 10),
    opening: AgentReply(
      text: text,
      plan: plan,
      blocks: [CaptionBlock(text), preview, const PlanBlock()],
    ),
  );
}

/// The answer to an amount tapped on the welcome: the goal it would write.
final AgentReply _goalReply = AgentReply(
  text:
      'Anoto R\$ 5.000 até 30 de novembro. Depois me conte o que você tem '
      'para entregar, que eu vejo se chega lá.',
  plan: AgentPlan(
    id: 'goal',
    changes: [
      PlanChange(
        kind: PlanChangeKind.addGoal,
        title: 'R\$ 5.000',
        minutes: 0,
        goal: PlanGoal(money: true, target: 5000, deadline: _monthEnd),
      ),
    ],
  ),
  blocks: [
    const CaptionBlock(
      'Anoto R\$ 5.000 até 30 de novembro. Depois me conte o que você tem '
      'para entregar, que eu vejo se chega lá.',
    ),
    PreviewBlock(
      items: [GoalPreview(target: 5000, start: _monthStart, end: _monthEnd)],
      applies: 'Aplicar anota a meta.',
    ),
    const PlanBlock(),
  ],
);

class _Agent extends DemoAgentRepository {
  _Agent(
    super.l10n, {
    required super.timeline,
    required super.artifacts,
    super.offer,
  });

  @override
  Future<({String conversationId, AgentReply reply})> turn(
    List<AgentEntry> history, {
    String? conversationId,
    DateTime? day,
    AgentSubject? about,
    String? suggestionId,
  }) async => (conversationId: 'c', reply: _goalReply);
}

class _Feed extends StatefulWidget {
  const _Feed();

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  late final _timeline = DemoTimelineRepository(
    context.l10n,
    resting: _scene == '1' || _scene == '2',
  );
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = _Agent(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
    offer: _suggestion(_scene),
  );

  var _seeded = false;

  /// A new person has nothing written: the demo's day and deliveries go,
  /// before anything reads them.
  void _seed() {
    if (_seeded) return;
    _seeded = true;
    if (_scene != '1' && _scene != '2') return;
    _artifacts.data = ArtifactsData(schedule: _artifacts.data.schedule);
    for (final (kind, id) in [
      (CardKind.task, 'mercado'),
      (CardKind.task, 'fotos'),
      (CardKind.event, 'standup'),
      (CardKind.event, 'dentista'),
    ]) {
      // Removed before its first await.
      unawaited(_timeline.delete(kind, id));
    }
  }

  @override
  Widget build(BuildContext context) {
    _seed();
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
          BlocProvider<TimelineModeCubit>(create: (_) => TimelineModeCubit()),
          BlocProvider<AgentCubit>(
            create: (context) =>
                AgentCubit(repository: context.read<AgentRepository>()),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => VoiceCubit(recognizer: const DemoVoiceRecognizer()),
          ),
          BlocProvider<ArtifactsCubit>(
            create: (_) => ArtifactsCubit(repository: _artifacts)..load(),
          ),
        ],
        child: const _Shell(),
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    if (_scene != '2') return;
    // The welcome's R$ 5.000, tapped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = context.l10n;
      final agent = context.read<AgentCubit>();
      unawaited(showAgentSheet(context, suggestion: _suggestion('2')));
      unawaited(agent.send(l10n.agentWelcomeSay(5000)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      extendBody: true,
      body: FeedPage(firstName: 'Marina', onOpen: (_) {}),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
      bottomNavigationBar: AppBottomBar(
        currentIndex: 0,
        onSelected: (_) {},
        items: [
          AppBottomBarItem(iconData: AppIcons.agent, label: l10n.shellFeedTab),
          AppBottomBarItem(iconData: AppIcons.plan, label: l10n.shellPlanTab),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}
