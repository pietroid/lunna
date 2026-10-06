import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/home/view/greeting.dart';
import 'package:timeline/timeline.dart';

/// {@template home_page}
/// The timeline: who you are and what time it is at the top, the switch
/// between the list and the calendar under it, and the day below.
///
/// There is no field on this screen. Writing something down starts from the
/// button at the foot of the app, which keeps this screen about what is
/// already there rather than about the next thing to add to it.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TimelineModeCubit>(
      create: (_) {
        final cubit = TimelineModeCubit();
        unawaited(cubit.restore());
        return cubit;
      },
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: const Column(
              children: [
                _Header(),
                TimelineModeSwitch(),
                Expanded(child: _Threads()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// {@template timeline_mode_switch}
/// Lista or Calendário: the tasks alone, in order, or the whole day to
/// scale. The phone remembers which.
/// {@endtemplate}
class TimelineModeSwitch extends StatelessWidget {
  /// {@macro timeline_mode_switch}
  const TimelineModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<TimelineModeCubit>().state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppSegmented(
          segments: [
            AppSegment(
              label: context.l10n.timelineModeList,
              iconData: AppIcons.prioritize,
            ),
            AppSegment(
              label: context.l10n.timelineModeCalendar,
              iconData: AppIcons.calendar,
            ),
          ],
          selected: TimelineMode.values.indexOf(mode),
          onSelected: (index) => context.read<TimelineModeCubit>().choose(
            TimelineMode.values[index],
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
                _Profile(greeting: greeting(context.l10n, now, firstName)),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  longDate(context.l10n, now),
                  style: AppTypography.label,
                ),
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

/// The greeting, and the account menu behind it: the routines, and signing
/// out.
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
          onTap: () => unawaited(context.push<void>('/rotina')),
          child: Row(
            children: [
              const AppIcon(iconData: AppIcons.repeat, size: AppSpacing.s5),
              const SizedBox(width: AppSpacing.s3),
              Text(context.l10n.homeRoutines),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => context.read<AppBloc>().add(const AppLogoutRequested()),
          child: Row(
            children: [
              const AppIcon(iconData: AppIcons.logout, size: AppSpacing.s5),
              const SizedBox(width: AppSpacing.s3),
              Text(context.l10n.homeSignOut),
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
    final guard = context.select<TimelineBloc, StartNowGuard?>(
      (bloc) => bloc.state.guard,
    );
    final busy = context.select<TimelineBloc, bool>(
      (bloc) => bloc.state.guardBusy,
    );
    final mode = context.watch<TimelineModeCubit>().state;

    return Stack(
      children: [
        const _MinuteRefresh(),
        TimelineList(
          // A list per mode, so each keeps its own scroll.
          key: ValueKey(mode),
          mode: mode,
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

  /// Opens the card: its header, its commands, and its notes.
  Future<void> _open(BuildContext context, TimelineEvent card) async {
    await context.push<void>('/evento/${Uri.encodeComponent(card.id)}');
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
