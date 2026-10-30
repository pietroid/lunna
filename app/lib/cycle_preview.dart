import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:cycle/cycle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/data/demo_repositories.dart';
import 'package:lunna/feed/feed.dart';
import 'package:lunna/menu/menu.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/tempo/tempo.dart';
import 'package:timeline/timeline.dart';

/// The cycle and the days off, against fixed data. `?s=<n>` picks the
/// scene: 1 Feed, 2 Menu, 3 Ciclo, 4 Folgas, 5 the calendar on a Friday
/// evening before a weekend off. Nothing ships from here.
void main() {
  final scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;
  // A Thursday morning on the second day of a period; the calendar's
  // scene the evening after, so the weekend is in sight.
  final at = scene == 5
      ? DateTime(2026, 10, 30, 21, 5)
      : DateTime(2026, 10, 29, 10);
  final shift = at.difference(DateTime.now());
  withClock(
    Clock(() => DateTime.now().add(shift)),
    () => runApp(_PreviewApp(scene: scene)),
  );
}

final _cycle = Cycle(lastStart: DateTime(2026, 10, 28));

const _rules = RestRules(saturday: DayKind.off, sunday: DayKind.off);

/// What the server would say of each of the next days: the weekend off,
/// the period light, the day of the cycle on every one.
List<DayMark> _marks(DateTime now) => [
  for (var i = -1; i < 21; i++)
    () {
      final day = DateTime(now.year, now.month, now.day + i);
      final phase = _cycle.phaseOn(day);
      final holiday = day == DateTime(2026, 11, 2);
      final weekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      final period = phase == CyclePhase.menstrual;
      return DayMark(
        day: day,
        kind: weekend || holiday
            ? DayKind.off
            : period
            ? DayKind.light
            : DayKind.work,
        reason: holiday
            ? DayReason.dayOff
            : weekend
            ? DayReason.weekend
            : period
            ? DayReason.period
            : null,
        budgetMinutes: period && !weekend ? _rules.lightMinutes : null,
        cycleDay: _cycle.dayOn(day),
        cycleLength: _cycle.length,
        phase: phase,
      );
    }(),
];

class _MarkedTimeline extends DemoTimelineRepository {
  _MarkedTimeline(super.l10n);

  @override
  Future<Timeline> fetch({int days = TimelineRepository.defaultDays}) async {
    final day = await super.fetch(days: days);
    final marks = _marks(clock.now());
    // What the server would do and the demo's arithmetic does not: no
    // task on a day off, nothing past the working day.
    bool kept(TimelineEvent card) =>
        !(card.isTask && marks.on(card.startTime)?.kind == DayKind.off) &&
        card.startTime.hour < 22;
    return Timeline(
      tasks: day.tasks.where(kept).toList(),
      backlog: day.backlog,
      cards: day.cards.where(kept).toList(),
      workDay: day.workDay,
      marks: marks,
    );
  }
}

class _FakeCycleRepository implements CycleRepository {
  _FakeCycleRepository(this.rhythm);

  Rhythm rhythm;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(rhythm);
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

class _Scene extends StatefulWidget {
  const _Scene({required this.scene});

  final int scene;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  late final _timeline = _MarkedTimeline(context.l10n);
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
    offer: AgentSuggestion(
      id: 'light-day',
      text: context.l10n.demoSuggestionLightDay,
    ),
  );
  late final _rhythm = Rhythm(
    cycle: _cycle,
    rules: _rules,
    daysOff: [
      DayOff(
        id: 'finados',
        day: DateTime(2026, 11, 2),
        title: context.l10n.demoDayOffSouls,
      ),
      DayOff(
        id: 'republica',
        day: DateTime(2026, 11, 20),
        title: context.l10n.demoDayOffRepublic,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>.value(value: _timeline),
        RepositoryProvider<AgentRepository>.value(value: _agent),
        RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
        RepositoryProvider<OpenDayHours>(create: (_) => OpenDayHours(() {})),
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
          BlocProvider<CycleCubit>(
            create: (_) => CycleCubit(
              repository: _FakeCycleRepository(_rhythm),
              initial: CycleState(status: CycleStatus.ready, data: _rhythm),
            ),
          ),
        ],
        child: Builder(builder: _page),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    final dock = AskDock(
      fab: AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
    );

    return switch (widget.scene) {
      3 => CyclePage(dock: dock),
      4 => DaysOffPage(dock: dock),
      _ => Scaffold(
        extendBody: true,
        body: switch (widget.scene) {
          2 => const MenuPage(),
          5 => PlanPage(tab: PlanTab.calendar, onSelected: (_) {}),
          _ => FeedPage(firstName: 'Marina', onOpen: (_) {}),
        },
        floatingActionButton: dock,
        floatingActionButtonLocation: AskDock.location,
        floatingActionButtonAnimator: AskDock.animator,
        bottomNavigationBar: AppBottomBar(
          currentIndex: switch (widget.scene) {
            2 => 2,
            5 => 1,
            _ => 0,
          },
          onSelected: (_) {},
          items: [
            AppBottomBarItem(
              iconData: AppIcons.agent,
              label: l10n.shellFeedTab,
            ),
            AppBottomBarItem(iconData: AppIcons.plan, label: l10n.shellPlanTab),
            AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
          ],
        ),
      ),
    };
  }
}
