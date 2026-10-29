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
import 'package:lunna/home/home.dart';
import 'package:timeline/timeline.dart';

/// What the demo is showing: the three things the landing page is about.
enum DemoChapter {
  /// A conversation with the agent, open over Tempo, ending in a plan.
  ask,

  /// Tempo: the day.
  time,

  /// Entregas: the deliveries, the goal and the month's hours.
  deliveries,
}

/// {@template demo_controller}
/// Which chapter the demo shows, and what it was last asked.
///
/// The landing page and the phone hold the same one: choosing a chapter
/// beside the phone changes the phone, and a tab tapped in the phone changes
/// the choice beside it.
/// {@endtemplate}
class DemoController extends ChangeNotifier {
  /// {@macro demo_controller}
  DemoController({this._chapter = DemoChapter.ask});

  DemoChapter _chapter;

  /// The chapter in front.
  DemoChapter get chapter => _chapter;

  /// What the agent is to be asked when [chapter] is [DemoChapter.ask]; null
  /// asks the first of the example asks.
  String? get question => _question;
  String? _question;

  /// Bumped on every request, so asking the same thing twice asks twice.
  int get turn => _turn;
  var _turn = 0;

  /// Brings [chapter] to the front.
  void show(DemoChapter chapter) {
    if (chapter == _chapter && chapter != DemoChapter.ask) return;
    _chapter = chapter;
    _question = null;
    _turn++;
    notifyListeners();
  }

  /// Opens the agent in the phone and asks it [text].
  void ask(String text) {
    _chapter = DemoChapter.ask;
    _question = text;
    _turn++;
    notifyListeners();
  }

  /// The tab moved inside the phone: follow it without asking anything.
  void _follow(DemoChapter chapter) {
    if (chapter == _chapter) return;
    _chapter = chapter;
    notifyListeners();
  }
}

/// {@template demo_app}
/// The app, running on the demo repositories inside whatever box it is
/// given: Tempo with the agent's bar, Entregas, and the agent's sheet.
///
/// It brings its own repositories, its own blocs and its own [Navigator], so
/// a card opened or a sheet raised from here stays inside the box instead of
/// covering the page around it. Nothing it does reaches a server.
/// {@endtemplate}
class DemoApp extends StatefulWidget {
  /// {@macro demo_app}
  const DemoApp({
    this.resting = false,
    this.late = 0,
    this.controller,
    this.suggestion,
    super.key,
  });

  /// Whether the day starts on a break instead of a running block.
  final bool resting;

  /// How many minutes past its end the running block is.
  final int late;

  /// Which chapter is in front; without one the demo opens on Tempo and
  /// stays wherever it is tapped to.
  final DemoController? controller;

  /// What the agent offers on Tempo, made with the demo's strings.
  final AgentSuggestion Function(AppLocalizations l10n)? suggestion;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  // Made on the first build, which is the first moment there is l10n.
  late final DemoTimelineRepository _timeline = DemoTimelineRepository(
    context.l10n,
    resting: widget.resting,
    late: widget.late,
  );
  late final DemoArtifactsRepository _artifacts = DemoArtifactsRepository(
    context.l10n,
  );
  late final DemoAgentRepository _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
    offer: widget.suggestion?.call(context.l10n),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

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
          // Not remembered: the demo opens the way the app does the first
          // time, on the calendar.
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
        child: ScaffoldMessenger(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _DemoShell(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shell as the app draws it, minus the Menu and the account.
class _DemoShell extends StatefulWidget {
  const _DemoShell({this.controller});

  final DemoController? controller;

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<_DemoShell> {
  var _index = 0;

  /// The request the sheet now open answers, so closing an older one does
  /// not move the chapter.
  var _asked = -1;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onChapter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChapter());
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onChapter);
    super.dispose();
  }

  void _onChapter() {
    final controller = widget.controller;
    if (controller == null || !mounted) return;
    final chapter = controller.chapter;
    final index = chapter == DemoChapter.deliveries ? 1 : 0;
    if (index == 1) unawaited(context.read<ArtifactsCubit>().load());
    if (index != _index) setState(() => _index = index);

    if (chapter != DemoChapter.ask) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (_asked == controller.turn) return;
    _asked = controller.turn;
    Navigator.of(context).popUntil((route) => route.isFirst);
    unawaited(_ask(controller));
  }

  /// Opens the agent's sheet and sends it the question, as typing it would.
  Future<void> _ask(DemoController controller) async {
    final turn = controller.turn;
    final question =
        controller.question ?? DemoAgentRepository.asks(context.l10n).first;
    final agent = context.read<AgentCubit>();
    final sheet = showAgentSheet(context, day: clock.now());
    unawaited(agent.send(question, day: clock.now()));
    await sheet;
    // Closed by hand: the phone is back on Tempo, and so is the page.
    if (mounted && controller.turn == turn) {
      controller._follow(DemoChapter.time);
    }
  }

  void _onSelected(int index) {
    // Only Tempo and Entregas are in the demo; the Menu is drawn and stays
    // where it is.
    if (index > 1) return;
    // Read again, as the app does, so a delivery a plan made is there.
    if (index == 1) unawaited(context.read<ArtifactsCubit>().load());
    setState(() => _index = index);
    widget.controller?._follow(
      index == 1 ? DemoChapter.deliveries : DemoChapter.time,
    );
  }

  void _writeDown() {
    if (_index == 1) {
      unawaited(showArtifactSheet(context));
      return;
    }
    unawaited(
      writeDownOnTimeline(
        context,
        placement:
            context.read<TimelineAim>().value ?? const Placement.backlog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fab = AppFab(
      tooltip: _index == 1 ? l10n.artifactsNew : l10n.shellWriteDown,
      onPressed: _writeDown,
    );

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [_DemoTempo(), ArtifactsPage()],
      ),
      // The agent's bar on every tab, as in the app.
      floatingActionButton: AskDock(day: clock.now, fab: fab),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: _onSelected,
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

/// Tempo as the app draws it, minus the account.
class _DemoTempo extends StatelessWidget {
  const _DemoTempo();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Column(
            children: [
              const _Header(),
              const TimelineModeSwitch(),
              // Empty on the landing page, which is offered nothing.
              BlocProvider<SuggestionCubit>(
                create: (context) {
                  final cubit = SuggestionCubit(
                    repository: context.read<AgentRepository>(),
                  );
                  unawaited(cubit.load());
                  return cubit;
                },
                child: const SuggestionCard(),
              ),
              Expanded(
                child: TimelineList(
                  key: ValueKey(context.watch<TimelineModeCubit>().state),
                  mode: context.watch<TimelineModeCubit>().state,
                  aim: context.read<TimelineAim>(),
                  onWriteDown: (placement) =>
                      writeDownOnTimeline(context, placement: placement),
                  onCardTap: (card) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventPage(id: card.id),
                    ),
                  ),
                  onDeliveryTap: (id) => openArtifact(context, id, tab: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: AppMinuteBuilder(
        builder: (context, now) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting(context.l10n, now, null),
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(longDate(context.l10n, now), style: AppTypography.label),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            const AppDayClock(),
          ],
        ),
      ),
    );
  }
}
