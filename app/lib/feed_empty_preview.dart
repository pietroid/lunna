import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/feed/feed.dart';
import 'package:timeline/timeline.dart';

/// The Feed's Agora with nothing running, scene by scene (`?s=<n>`):
///
/// 1. the break, with the next task today;
/// 2. the break, with nothing queued at all;
/// 3. after the working day, with tomorrow's first task;
/// 4. after the working day, with nothing queued.
///
/// Nothing ships from here.
void main() {
  final scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;
  final today = DateTime.now();
  final hour = scene <= 2 ? 10 : 22;
  final now = DateTime(today.year, today.month, today.day, hour, 20);
  withClock(Clock.fixed(now), () => runApp(_Preview(scene: scene, now: now)));
}

class _Preview extends StatelessWidget {
  const _Preview({required this.scene, required this.now});

  final int scene;
  final DateTime now;

  TimelineEvent _task(String id, String title, DateTime start, int minutes) =>
      TimelineEvent(
        id: id,
        title: title,
        section: TimelineSection.dia,
        kind: CardKind.task,
        startTime: start,
        endTime: start.add(Duration(minutes: minutes)),
        durationMinutes: minutes,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(const Locale('pt'));
    final day = DateTime(now.year, now.month, now.day);
    final cards = switch (scene) {
      1 => [
        _task('a', 'Revisar o contrato da Renata', day.add(
          const Duration(hours: 11, minutes: 10),
        ), 45),
      ],
      3 => [
        _task('b', 'Responder e-mails', day.add(
          const Duration(days: 1, hours: 7),
        ), 30),
      ],
      _ => const <TimelineEvent>[],
    };

    return RepositoryProvider<AgentRepository>.value(
      value: _NoAgent(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineBloc>(
            create: (_) => _FixedTimeline(TimelineState(
              status: TimelineStatus.success,
              cards: cards,
            )),
          ),
          BlocProvider(
            create: (_) => ArtifactsCubit(
              repository: DemoArtifactsRepository(l10n),
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: demoArtifacts(l10n),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            extendBody: true,
            body: FeedPage(firstName: 'Pietro', onOpen: (_) {}),
            floatingActionButton: AppFab(onPressed: () {}),
            bottomNavigationBar: AppBottomBar(
              currentIndex: 0,
              onSelected: (_) {},
              items: [
                AppBottomBarItem(
                  iconData: AppIcons.agent,
                  label: l10n.shellFeedTab,
                ),
                AppBottomBarItem(
                  iconData: AppIcons.plan,
                  label: l10n.shellPlanTab,
                ),
                AppBottomBarItem(
                  iconData: AppIcons.menu,
                  label: l10n.shellMenuTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedTimeline extends TimelineBloc {
  _FixedTimeline(TimelineState state) : super(repository: _NoTimeline()) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state);
  }
}

class _NoTimeline implements TimelineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAgent implements AgentRepository {
  @override
  Future<AgentSuggestion?> suggestion() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
