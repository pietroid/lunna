import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:lunna/plan/view/write_task.dart';
import 'package:lunna/tempo/view/minute_refresh.dart';
import 'package:timeline/timeline.dart';

/// {@template day_page}
/// Ver o dia: the calendar, to scale, day after day, on a page of its own
/// over Plano. The same calendar Tempo drew: a drop on Agora begins a task,
/// free room and its + write there, and the + at the foot writes on the
/// first free hour in sight.
///
/// It is handed what the shell keeps for it ([TimelineAim],
/// [OpenDayHours], [WorkOnDay]), since a pushed page is not under the
/// shell.
/// {@endtemplate}
class DayPage extends StatelessWidget {
  /// {@macro day_page}
  const DayPage({super.key});

  /// Pushes the page, with what the shell keeps for it.
  static Future<void> open(BuildContext context) {
    final aim = context.read<TimelineAim>();
    final hours = context.read<OpenDayHours>();
    final workOn = context.read<WorkOnDay>();
    final links = context.read<AgentLinks>();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TimelineAim>.value(value: aim),
            RepositoryProvider<OpenDayHours>.value(
              // Mudar horário leaves the calendar for the Menu.
              value: OpenDayHours(() {
                Navigator.of(context).popUntil((route) => route.isFirst);
                hours.open();
              }),
            ),
            RepositoryProvider<WorkOnDay>.value(value: workOn),
            RepositoryProvider<AgentLinks>.value(value: links),
          ],
          child: const DayPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aim = context.read<TimelineAim>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(context.l10n.dayPageTitle, style: AppTypography.title),
        actions: const [
          // The agent's last plan, while it can be taken back.
          UndoChip(),
          SizedBox(width: AppSpacing.s4),
        ],
      ),
      body: const _Threads(),
      floatingActionButton: AskDock(
        // The conversation is about the day on screen.
        day: () => aim.value?.at,
        fab: AppFab(
          tooltip: context.l10n.shellWriteDown,
          onPressed: () => unawaited(
            writeTask(
              context,
              placement: aim.value ?? const Placement.backlog(),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: AskDock.location,
      floatingActionButtonAnimator: AskDock.animator,
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
    return Stack(
      children: [
        MinuteRefresh(onRefresh: () => _refresh(context)),
        TimelineList(
          onCardTap: (card) => openCard(context, card),
          // A delivery's card is the delivery: it opens on what is left to
          // do of it.
          onDeliveryTap: (id) => unawaited(openArtifact(context, id, tab: 1)),
          // Where the button at the foot of the app writes follows the day
          // on screen, so it is kept above this screen, where the button is.
          aim: context.read<TimelineAim>(),
          // Tapping empty room, or a +, is writing something down there.
          onWriteDown: (placement) =>
              unawaited(writeTask(context, placement: placement)),
          // Once the day is over, Agora offers to change when it ends.
          onAdjustDay: context.read<OpenDayHours>().open,
          // A weekend day off can be put back to work from the calendar.
          onWorkOn: context.read<WorkOnDay>().workOn,
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

/// {@template work_on_day}
/// Puts one day of the weekend back to work, which a weekend's rest row
/// offers on the calendar. The shell answers it with the rhythm's cubit.
/// {@endtemplate}
final class WorkOnDay {
  /// {@macro work_on_day}
  const WorkOnDay(this.workOn);

  /// Puts the day back to work.
  final ValueChanged<DateTime> workOn;
}
