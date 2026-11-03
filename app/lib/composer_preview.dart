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

/// The composer's mockup: Plano with the one button, and the sheet it opens
/// in each state. `?s=<n>` picks the scene. Nothing ships from here.
///
/// 1. Plano: the plus, alone at the foot.
/// 2. The sheet, recording: the words rise in the field.
/// 3. Read as an event: the summary over the sheet.
/// 4. Read as a task under a task, with its subtasks.
/// 5. A request that changes the day: the plan, shortly.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _PreviewApp()));
}

final int _scene =
    int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

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
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = DemoAgentRepository(
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
        child: const _Shell(),
      ),
    );
  }
}

/// Plano under the bottom bar, with the one button where the dock was.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final _voice = _SeededVoice(_scene == 2 ? _recording() : null);
  late final _compose = ComposeCubit(
    read: (_) async => _draft()!,
    initial: _seed(context.l10n),
  );

  @override
  void initState() {
    super.initState();
    if (_scene > 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_open()),
      );
    }
  }

  Future<void> _open() =>
      showComposer(context, cubit: _compose, voice: _voice);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      body: HomePage(onSeeDay: () {}, onOpenLater: () {}),
      floatingActionButton: ComposeButton(onPressed: () => unawaited(_open())),
      floatingActionButtonLocation: AppFab.location,
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

DateTime _today(int hour) {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day, hour);
}

/// What each scene's request was read as.
ComposeDraft? _draft() => switch (_scene) {
  3 => ComposeDraft(
    kind: ComposeKind.event,
    title: 'Sessão com a Carla',
    start: _today(15).add(const Duration(days: 1)),
    minutes: 60,
  ),
  4 => const ComposeDraft(
    kind: ComposeKind.task,
    title: 'Gravar o reels da Lua cheia',
    minutes: 90,
    parent: 'Post: Lua cheia em Touro',
    subtasks: ['Roteiro', 'Gravar', 'Editar e legendar'],
  ),
  5 => const ComposeDraft(
    kind: ComposeKind.plan,
    title: 'Sessão da Renata às 16h',
    changes: [
      'Mapa astral · Renata vai das 14:00 para as 16:00',
      'Revisar o mapa da Júlia sobe para as 14:00',
      'Post: Lua cheia em Touro vai para amanhã',
    ],
  ),
  _ => null,
};

ComposeState _seed(AppLocalizations l10n) {
  final draft = _draft();
  final text = switch (_scene) {
    3 => 'Sessão com a Carla amanhã às 15h, uma hora',
    4 =>
      'Gravar o reels da Lua cheia pro post de Touro, uma hora e meia: '
          'roteiro, gravar, editar e legendar',
    5 => 'A sessão da Renata passou pras 16h, ajeita minha tarde',
    _ => '',
  };
  if (draft == null) return ComposeState(text: text);
  return ComposeState(status: ComposeStatus.ready, text: text, draft: draft);
}

VoiceState _recording() => const VoiceState(
  status: VoiceStatus.listening,
  heard: 'Gravar o reels da Lua cheia pro post de Touro, uma hora e meia:',
  hearing: 'roteiro, gravar, editar e legendar',
  elapsed: Duration(seconds: 7),
  levels: [
    0.2, 0.5, 0.8, 0.6, 0.3, 0.7, 0.9, 0.4, 0.2, 0.1, 0.5, 0.8, //
    0.6, 0.9, 0.7, 0.3, 0.5, 0.6, 0.4, 0.8, 0.5, 0.2, 0.6, 0.7,
  ],
);

/// A voice cubit that starts where the scene says.
class _SeededVoice extends VoiceCubit {
  _SeededVoice(VoiceState? seed)
    : super(recognizer: const DemoVoiceRecognizer()) {
    if (seed != null) emit(seed);
  }
}
