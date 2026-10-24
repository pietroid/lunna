import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/routines/routines.dart';
import 'package:timeline/timeline.dart';

/// The agent's bar on every screen, on fakes. `?s=<n>`:
/// 1 Entregas, 2 Menu, 3 Rotina, 4 Feitas, 5 a delivery's notes.
void main() {
  // The demo's 10:00, so the day and Feitas read the same on every run.
  final start = DateTime.now();
  final ten = DateTime(start.year, start.month, start.day, DemoClock.hour);
  withClock(
    Clock(() => ten.add(DateTime.now().difference(start))),
    () => runApp(const _PreviewApp()),
  );
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
      home: const _Fakes(),
    );
  }
}

class _Fakes extends StatefulWidget {
  const _Fakes();

  @override
  State<_Fakes> createState() => _FakesState();
}

class _FakesState extends State<_Fakes> {
  late final _timeline = _PreviewTimeline(context.l10n);
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
        RepositoryProvider<RoutinesRepository>.value(
          value: _PreviewRoutines(context.l10n),
        ),
        RepositoryProvider<VoiceRecognizer>.value(
          value: const DemoVoiceRecognizer(),
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
            create: (_) => ArtifactsCubit(
              repository: _artifacts,
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: _artifacts.data,
              ),
            ),
          ),
        ],
        child: switch (_scene) {
          3 => const RoutinesPage(),
          4 => BlocProvider(
            create: (context) {
              final cubit = DoneArchiveCubit(
                repository: context.read<TimelineRepository>(),
              );
              unawaited(cubit.load());
              return cubit;
            },
            child: Builder(
              builder: (context) => DoneArchivePage(
                onOpen: (_) async {},
                dock: AskDock(
                  fab: AppFab(
                    tooltip: context.l10n.shellWriteDown,
                    onPressed: () => unawaited(writeDownOnTimeline(context)),
                  ),
                ),
              ),
            ),
          ),
          5 => const ArtifactPage(id: 'post', initialTab: 0),
          _ => _PreviewShell(index: _scene == 2 ? 2 : 1),
        },
      ),
    );
  }
}

/// The shell as `ShellPage` now draws it: the same dock on every tab.
class _PreviewShell extends StatefulWidget {
  const _PreviewShell({required this.index});

  final int index;

  @override
  State<_PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<_PreviewShell> {
  late int _index = widget.index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [SizedBox.shrink(), ArtifactsPage(), MenuPage()],
      ),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(
          tooltip: _index == 1 ? l10n.artifactsNew : l10n.shellWriteDown,
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
            iconData: AppIcons.time,
            label: l10n.shellTimelineTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.artifacts,
            label: l10n.shellArtifactsTab,
          ),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}

/// The demo's day, with a few tasks already done for Feitas.
class _PreviewTimeline extends DemoTimelineRepository {
  _PreviewTimeline(super.l10n);

  @override
  Future<List<TimelineEvent>> fetchDone({
    TimelineEvent? after,
    String query = '',
    int limit = TimelineRepository.donePage,
  }) async {
    if (after != null) return const [];
    final now = clock.now();
    TimelineEvent done(String id, String title, int daysAgo, int hour) {
      final at = DateTime(now.year, now.month, now.day - daysAgo, hour, 40);
      return TimelineEvent(
        id: id,
        title: title,
        section: TimelineSection.dia,
        startTime: at,
        endTime: at.add(const Duration(minutes: 30)),
        durationMinutes: 30,
      );
    }

    return [
      done('d1', 'Responder o e-mail da contadora', 0, 9),
      done('d2', 'Revisar o contrato do estúdio', 0, 8),
      done('d3', 'Mandar o orçamento para a Júlia', 1, 17),
      done('d4', 'Pagar o boleto do aluguel', 1, 11),
      done('d5', 'Gravar o áudio do post', 1, 10),
      done('d6', 'Comprar café e filtro', 2, 18),
      done('d7', 'Ligar para o dentista', 2, 9),
    ];
  }
}

/// Three routines across the day.
class _PreviewRoutines implements RoutinesRepository {
  _PreviewRoutines(this.l10n);

  final AppLocalizations l10n;

  @override
  Future<List<Routine>> fetchRoutines() async => const [
    Routine(
      id: 'r1',
      title: 'Café e meditação',
      hour: 7,
      minute: 30,
      durationMinutes: 45,
      days: RoutineDays.daily,
      checklist: ['Café', 'Meditar', 'Louça'],
    ),
    Routine(
      id: 'r2',
      title: 'Almoço',
      hour: 12,
      minute: 30,
      durationMinutes: 60,
      days: RoutineDays.daily,
      fixed: true,
    ),
    Routine(
      id: 'r3',
      title: 'Caminhada',
      hour: 18,
      minute: 0,
      durationMinutes: 40,
      days: RoutineDays.daily,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
