import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/plan/plan.dart';
import 'package:lunna/tempo/view/tempo_page.dart';
import 'package:timeline/timeline.dart';

/// UI and UX, part 4: Plano with Em seguida as a queue, a card carried in
/// it, play on a long task, and the calendar's Agora. `?s=<n>` picks the
/// scene. Nothing ships from here.
///
/// 1. Plano: Agora, Em seguida headed as Agora is, play on every task, the
///    composer's one button.
/// 2. A card of Em seguida carried up: its quiet copy where it would land.
/// 3. Play on a task of two hours: how much now.
/// 4. Ver o dia: Agora's task with the round play on the left.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _PreviewApp()));
}

/// Set by a test to pick a scene.
int? debugScene;

int get _scene =>
    debugScene ?? int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

const _script = 'Escrever o roteiro do curso';
const _call = 'Ligar para a contadora';
const _groceries = 'Comprar leite e ovos';

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
  late final Future<void> _seeded = _seed();

  /// A fuller morning than the demo's: a long task, a few short ones and
  /// lunch, after what runs.
  Future<void> _seed() async {
    final now = clock.now();
    for (final (title, minutes) in [
      (_call, 15),
      (_script, 120),
      ('Responder os e-mails da semana', 25),
      ('Revisar o mapa da Júlia', 50),
      ('Separar as fotos do ensaio', 40),
    ]) {
      await _timeline.createTask(
        title: title,
        minutes: minutes,
        placement: const Placement.queue(99),
      );
    }
    await _timeline.createEvent(
      title: 'Almoço com a Bia',
      durationMinutes: 60,
      startTime: DateTime(now.year, now.month, now.day, 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _seeded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: AppColors.bg);
        }
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TimelineRepository>.value(value: _timeline),
            RepositoryProvider<AgentRepository>.value(value: _agent),
            RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
            RepositoryProvider<AgentLinks>.value(
              value: const AgentLinks(preview: drawAgentPreview),
            ),
            RepositoryProvider<OpenDayHours>.value(value: OpenDayHours(() {})),
            RepositoryProvider<WorkOnDay>.value(value: WorkOnDay((_) {})),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<TimelineBloc>(
                create: (context) =>
                    TimelineBloc(repository: context.read<TimelineRepository>())
                      ..add(const TimelineRequested()),
              ),
              BlocProvider<VoiceCubit>(
                create: (_) =>
                    VoiceCubit(recognizer: const DemoVoiceRecognizer()),
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
            // Pages pushed from Plano (Ver o dia) are under the providers.
            child: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const _Shell()),
            ),
          ),
        );
      },
    );
  }
}

/// Plano under the bottom bar, with the composer's one button.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    if (_scene == 2) unawaited(_carry());
    if (_scene == 3) unawaited(_play());
    if (_scene == 4) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(DayPage.open(context)),
      );
    }
  }

  /// Holds the call's card and carries it up over the groceries, with a
  /// finger made of pointer events: the real drag, held mid-air.
  Future<void> _carry() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final held = _centreOf(_call);
    if (held == null) return;
    final from = held;
    final binding = GestureBinding.instance
      ..handlePointerEvent(PointerDownEvent(pointer: 7, position: from));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final to = _centreOf(_groceries, last: false) ?? from;
    if (!mounted) return;
    var at = from;
    Future<void> glide(Offset to) async {
      final start = at;
      for (var i = 1; i <= 10; i++) {
        final next = Offset.lerp(start, to, i / 10)!;
        binding.handlePointerEvent(
          PointerMoveEvent(pointer: 7, position: next, delta: next - at),
        );
        at = next;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }

    // Up over the groceries, which opens the copy above them; then down
    // onto the groceries (pushed down by it), so the copy shows.
    await glide(to);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await glide(to.translate(0, 44));
  }

  Future<void> _play() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final card = context.read<TimelineBloc>().state.cards.firstWhere(
      (c) => c.title == _script,
    );
    await PlaySheet.show(context, PlaySheet.task(card: card));
  }

  /// The middle of the first (or last) text reading [title] on screen.
  Offset? _centreOf(String title, {bool last = true}) {
    Offset? found;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Text && widget.data == title) {
        final box = element.renderObject as RenderBox?;
        if (box != null && box.hasSize) {
          final centre = box.localToGlobal(box.size.center(Offset.zero));
          if (found == null || last) found = centre;
        }
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      body: HomePage(onSeeDay: () {}, onOpenLater: () {}),
      floatingActionButton: ComposeButton(onPressed: () {}),
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
