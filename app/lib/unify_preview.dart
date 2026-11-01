import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/plan/view/home_page.dart';
import 'package:lunna/plan/view/task_pages.dart';
import 'package:timeline/timeline.dart';

/// The design of #77 (tasks and deliveries are one thing; Plano is the
/// home), drawn by the real widgets on fakes. `?s=<n>` picks the scene:
///
/// 1. Plano, the top: the offer, Agora with the day's mark, the next.
/// 2. Plano, scrolled: Pendentes and Para depois.
/// 3. Ver o dia: the calendar on a page of its own.
/// 4. Para depois, whole.
/// 5. The creation sheet: Tarefa or Evento, and the product.
/// 6. A task's page: Agora and Para depois of its tasks.
///
/// Nothing ships from here.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _App()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

class _App extends StatelessWidget {
  const _App();

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

/// The demo's repositories and blocs, as the app holds them.
class _Fakes extends StatefulWidget {
  const _Fakes();

  @override
  State<_Fakes> createState() => _FakesState();
}

class _FakesState extends State<_Fakes> {
  late final _timeline = DemoTimelineRepository(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: DemoArtifactsRepository(context.l10n),
    offer: const AgentSuggestion(
      id: 'offer',
      text:
          'O mapa da Júlia é para terça e ainda faltam 1h30. Encaixo 45 min '
          'às 11:00, depois da Marina?',
    ),
  );

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
            create: (_) =>
                TimelineBloc(repository: _timeline)
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<TimelineModeCubit>(create: (_) => TimelineModeCubit()),
          BlocProvider<AgentCubit>(
            create: (_) => AgentCubit(repository: _agent),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => VoiceCubit(recognizer: const DemoVoiceRecognizer()),
          ),
          BlocProvider<SuggestionCubit>(
            create: (_) => SuggestionCubit(repository: _agent)..load().ignore(),
          ),
        ],
        child: switch (_scene) {
          3 => const _DayPage(),
          4 => LaterPage(tasks: _queue),
          6 => const _TaskScene(),
          _ => const _Shell(),
        },
      ),
    );
  }
}

/// The tabs: Plano, Objetivos, Menu.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final _scroll = ScrollController(
    initialScrollOffset: _scene == 2 ? 470 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (_scene == 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = clock.now();
        unawaited(
          AppPromptSheet.show(
            context,
            previewFor: (_) => now.add(const Duration(minutes: 55)),
            initialText: 'Ajustar o rodapé do site',
            initialDuration: const Duration(minutes: 45),
            products: const [
              'Site',
              'Mapa astral',
              'Post',
              'Identidade visual',
            ],
            initialProduct: 'Site',
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      body: HomePage(data: _home, controller: _scroll),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(onPressed: () {}),
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

/// Ver o dia: the calendar Tempo draws today, on its own page.
class _DayPage extends StatelessWidget {
  const _DayPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(iconData: AppIcons.back, onPressed: () {}),
        titleSpacing: 0,
        title: Text(context.l10n.dayPageTitle, style: AppTypography.title),
        actions: const [
          UndoChip(),
          SizedBox(width: AppSpacing.s4),
        ],
      ),
      body: TimelineList(
        onCardTap: (_) {},
        aim: context.read<TimelineAim>(),
      ),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(onPressed: () {}),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
    );
  }
}

class _TaskScene extends StatelessWidget {
  const _TaskScene();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TaskPage(
      title: 'Site da Clínica Aurora',
      product: r'Site · R$ 4.800',
      status: '6h20 de 12h · até sex, 6 nov',
      bar: const TaskBar(done: 0.53, time: 0.58),
      now: TaskView(
        title: 'Revisar os textos da home',
        trailing: '09:40–10:30',
        status: l10n.nowLeft('30 min'),
        bar: const TaskBar(done: 0.4),
        playing: true,
      ),
      later: const [
        TaskView(title: 'Trocar as fotos da equipe', trailing: '45 min'),
        TaskView(title: 'Formulário de agendamento', trailing: '1h30'),
        TaskView(title: 'Publicar e testar no celular', trailing: '1h'),
        TaskView(title: 'Enviar o link para a Dra. Aurora', trailing: '15 min'),
      ],
      done: 5,
    );
  }
}

final _later = [
  const TaskView(
    title: 'Post de lançamento · Studio Nori',
    subtitle: 'Post · 3 tarefas',
    trailing: '1h30',
  ),
  const TaskView(title: 'Planejar a semana', trailing: '30 min'),
  const TaskView(
    title: 'Mapa astral do Pedro',
    subtitle: 'Mapa astral · até qui, 12 nov',
    trailing: '3h',
  ),
  const TaskView(title: 'Organizar as notas fiscais', trailing: '45 min'),
];

final List<TaskView> _queue = [
  ..._later,
  const TaskView(
    title: 'Identidade visual · Ateliê Lume',
    subtitle: 'Identidade visual · 6 tarefas',
    trailing: '10h',
  ),
  const TaskView(title: 'Renovar o domínio do portfólio', trailing: '15 min'),
  const TaskView(
    title: 'Carrossel sobre Mercúrio retrógrado',
    subtitle: 'Post · até seg, 16 nov',
    trailing: '2h',
  ),
  const TaskView(title: 'Ligar para o contador', trailing: '20 min'),
  const TaskView(
    title: 'Mapa astral da Beatriz',
    subtitle: 'Mapa astral · 4 tarefas',
    trailing: '3h',
  ),
  const TaskView(title: 'Atualizar a tabela de preços', trailing: '45 min'),
  const TaskView(title: 'Backup das fotos de outubro', trailing: '30 min'),
  const TaskView(title: 'Ler sobre trânsitos de Saturno', trailing: '1h'),
];

HomeData get _home {
  final now = clock.now();
  return HomeData(
    mark: DayMark(
      day: DateTime(now.year, now.month, now.day),
      kind: DayKind.light,
      cycleDay: 2,
      cycleLength: 28,
      phase: CyclePhase.menstrual,
      budgetMinutes: 180,
    ),
    now: const TaskView(
      title: 'Site da Clínica Aurora',
      subtitle: 'Revisar os textos da home',
      trailing: '09:40–10:30',
      status: 'Faltam 30 min',
      bar: TaskBar(done: 0.4),
      playing: true,
    ),
    next: const TaskView(
      title: 'Responder a Marina sobre o orçamento',
      trailing: '10:35–10:50',
    ),
    pending: const [
      TaskView(
        title: 'Mapa astral da Júlia',
        subtitle: 'Interpretar as casas',
        status: '1h30 de 3h · até ter, 3 nov',
        statusInk: AppColors.dangerInk,
        bar: TaskBar(done: 0.5, time: 0.8),
      ),
      TaskView(
        title: 'Identidade visual · Café Brasa',
        subtitle: 'Testar as paletas',
        status: '4h de 10h · até sex, 13 nov',
        bar: TaskBar(done: 0.4, time: 0.35),
      ),
      TaskView(
        title: 'Ler o contrato da editora',
        status: 'Pausado · faltam 25 min',
        bar: TaskBar(done: 0.45),
      ),
    ],
    later: _later,
    laterMore: _queue.length - _later.length,
  );
}
