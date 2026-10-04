import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/home/view/greeting.dart';
import 'package:go_router/go_router.dart';

/// {@template home_page}
/// The timeline: who you are and what time it is at the top, and the three
/// lists below it.
///
/// There is no field on this screen, and no orb either. Typing is a
/// deliberate act that starts from the bar at the foot of the app, which
/// keeps this screen about what is already there rather than about the next
/// thing to add to it.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: const Column(
            children: [
              _Header(),
              Expanded(child: _Threads()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The greeting, the date, and the clock.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The greeting is the account: it is the only thing on the
                // screen that names the person, so it is also the only thing
                // that opens their menu.
                _Profile(greeting: greeting(now, firstName)),
                const SizedBox(height: AppSpacing.s1),
                Text(PtDate.long(now), style: AppTypography.label),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          const AppDayClock(),
        ],
      ),
    );
  }
}

/// The greeting, and the account menu behind it.
class _Profile extends StatelessWidget {
  const _Profile({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      padding: EdgeInsets.zero,
      tooltip: '',
      offset: const Offset(0, AppSpacing.s8),
      constraints: const BoxConstraints(minWidth: AppSpacing.s12 * 3),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => context.read<AppBloc>().add(const AppLogoutRequested()),
          child: const Row(
            children: [
              AppIcon(iconData: AppIcons.logout, size: AppSpacing.s5),
              SizedBox(width: AppSpacing.s3),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Text(
        greeting,
        style: AppTypography.headline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Threads extends StatelessWidget {
  const _Threads();

  @override
  Widget build(BuildContext context) {
    final guard = context.select<TimelineBloc, A2uiComponent?>(
      (bloc) => bloc.state.guard,
    );
    final busy = context.select<TimelineBloc, bool>(
      (bloc) => bloc.state.guardBusy,
    );

    return Stack(
      children: [
        const _MinuteRefresh(),
        TimelineList(
          onCardTap: (card) => _open(context, card),
          // Tapping empty room is writing something down there.
          onFreeTap: (tap) => unawaited(writeDownOnTimeline(context, tap: tap)),
        ),
        // The guard is drawn over the timeline rather than pushed as a route:
        // the question is about a card that is still on screen, and the
        // answer puts it somewhere the user can see from here.
        if (guard != null) GuardSheet(guard: guard, busy: busy),
      ],
    );
  }

  /// Opens the block: its header, its commands, and the conversation about
  /// it when the user wants one.
  Future<void> _open(BuildContext context, TimelineEvent card) async {
    await context.push<void>('/evento/${Uri.encodeComponent(card.id)}');

    // The card's preview changes while the conversation is open, so the day
    // is refetched on the way back rather than left stale.
    if (context.mounted) {
      context.read<TimelineBloc>().add(const TimelineRequested());
    }
  }
}

/// Refetches the timeline on the minute, and draws nothing.
///
/// Which list a timed card is in is worked out from the clock, on the server,
/// when the list is read. So a card only walks into Agora as its hour comes
/// round if somebody asks for the list again: this is the asking, and it is
/// the whole of the minute-by-minute routine the timeline needs.
///
/// It is a widget with its own timer rather than a rebuild hook, because the
/// fetch has to happen on the tick and not on the rebuild. Asking from inside
/// a build would ask again for every state the answer produced.
class _MinuteRefresh extends StatefulWidget {
  const _MinuteRefresh();

  @override
  State<_MinuteRefresh> createState() => _MinuteRefreshState();
}

class _MinuteRefreshState extends State<_MinuteRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Wakes on the next minute boundary, not a minute from now, so the list
  /// turns over at the same moment the clock above it does.
  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: now.minute + 1));

    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      _refresh();
      _schedule();
    });
  }

  void _refresh() {
    final bloc = context.read<TimelineBloc>();

    // Not while a guard is up. The lists behind it are the ones from before
    // the drag, and replacing them under an open question would be the screen
    // answering it.
    if (bloc.state.guard != null) return;

    bloc.add(const TimelineRequested());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
