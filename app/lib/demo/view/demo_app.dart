import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/demo/data/demo_repositories.dart';
import 'package:focus/home/home.dart';

/// {@template demo_app}
/// The timeline, running on the demo repositories inside whatever box it is
/// given.
///
/// It brings its own repositories, its own [TimelineBloc] and its own
/// [Navigator], so a card opened or a sheet raised from here stays inside the
/// box instead of covering the page around it. Nothing it does reaches a
/// server.
/// {@endtemplate}
class DemoApp extends StatelessWidget {
  /// {@macro demo_app}
  const DemoApp({this.resting = false, super.key});

  /// Whether the day starts on a break instead of a running block.
  final bool resting;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>(
          create: (_) => DemoTimelineRepository(resting: resting),
        ),
        RepositoryProvider<ChatRepository>(
          create: (_) => DemoChatRepository(),
        ),
      ],
      child: BlocProvider<TimelineBloc>(
        create: (context) =>
            TimelineBloc(repository: context.read<TimelineRepository>())
              ..add(const TimelineRequested()),
        child: ScaffoldMessenger(
          child: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const _DemoHome()),
          ),
        ),
      ),
    );
  }
}

/// The home screen as the app draws it, minus the account.
class _DemoHome extends StatelessWidget {
  const _DemoHome();

  Future<void> _schedule(BuildContext context) async {
    final bloc = context.read<TimelineBloc>();
    final result = await AppPromptSheet.show(
      context,
      previewFor: (duration) =>
          TimelinePlan.nextFreeStart(bloc.state.cards, duration),
    );
    if (result == null) return;

    bloc.add(
      EventCreated(
        title: result.text,
        durationMinutes: result.duration.inMinutes,
        fixed: result.fixed,
        startTime: result.startTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: TimelineList(
                    onCardTap: (card) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventPage(id: card.id),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Only Tempo is in the demo, so the other destinations are drawn and
      // stay where they are.
      bottomNavigationBar: AppBottomBar(
        currentIndex: 0,
        onSelected: (_) {},
        center: AppOrb(onTap: () => _schedule(context)),
        items: const [
          AppBottomBarItem(iconData: AppIcons.time, label: 'Tempo'),
          AppBottomBarItem(iconData: AppIcons.things, label: 'Coisas'),
          AppBottomBarItem(
            iconData: AppIcons.conversations,
            label: 'Conversas',
          ),
          AppBottomBarItem(iconData: AppIcons.menu, label: 'Menu'),
        ],
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
                  Text(greeting(now, null), style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.s1),
                  Text(PtDate.long(now), style: AppTypography.label),
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
