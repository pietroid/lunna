import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/view/minute_refresh.dart';
import 'package:timeline/timeline.dart';

/// {@template home_page}
/// Tarefas, in Painel: the switch between the list and the calendar, and
/// the day below.
///
/// The greeting, the clock and the agent's offer are on the Lunna tab
/// (`OverviewPage`); this screen is the day itself. Which way it is drawn
/// is kept above it ([TimelineModeCubit], given by the shell), so the Lunna
/// tab can open it on the calendar.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TimelineModeSwitch(),
        Expanded(child: _Threads()),
      ],
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
      child: Row(
        children: [
          AppSegmented(
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
          const Spacer(),
          // The agent's last plan, while it can be taken back. It stays
          // until the day is changed by hand rather than timing out.
          const UndoChip(),
        ],
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
        MinuteRefresh(onRefresh: () => _refresh(context)),
        TimelineList(
          // A list per mode, so each keeps its own scroll.
          key: ValueKey(mode),
          mode: mode,
          onCardTap: (card) => _open(context, card),
          // In Lista a delivery's card is the delivery: it opens on what is
          // left to do of it.
          onDeliveryTap: (id) => unawaited(openArtifact(context, id, tab: 1)),
          // Where the button at the foot of the app writes follows the day
          // on screen, so it is kept above this screen, where the button is.
          aim: context.read<TimelineAim>(),
          // Tapping empty room, or a +, is writing something down there.
          onWriteDown: (placement) => unawaited(
            writeDownOnTimeline(context, placement: placement),
          ),
          // Once the day is over, Agora offers to change when it ends.
          onAdjustDay: context.read<OpenDayHours>().open,
        ),
        // The guard is drawn over the timeline rather than pushed as a route:
        // the question is about a card that is still on screen, and the
        // answer puts it somewhere the user can see from here.
        if (guard != null) GuardSheet(guard: guard, busy: busy),
      ],
    );
  }

  /// Asks for the day again on the minute ([MinuteRefresh]).
  void _refresh(BuildContext context) {
    final bloc = context.read<TimelineBloc>();

    // Not while a guard is up. The lists behind it are the ones from before
    // the drag, and replacing them under an open question would be the screen
    // answering it.
    if (bloc.state.guard != null) return;

    bloc.add(const TimelineRequested());
  }

  /// Opens the card: its header, its commands, and its notes.
  Future<void> _open(BuildContext context, TimelineEvent card) async {
    await context.push<void>('/evento/${Uri.encodeComponent(card.id)}');
  }
}

/// {@template open_day_hours}
/// Takes the user to where the working day's hours are set, which Agora
/// offers once the day is over. The shell answers it with the Menu tab.
/// {@endtemplate}
final class OpenDayHours {
  /// {@macro open_day_hours}
  const OpenDayHours(this.open);

  /// Goes there.
  final VoidCallback open;
}
