import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/play/play.dart';

/// {@template guard_sheet}
/// The one question a drag can raise, drawn over the timeline.
///
/// Something is running and a card was just dropped at the top of the day,
/// by a road that did not ask first (play asks before it posts, #89). One
/// yes or no ([PauseQuestion]): yes pauses what runs into Pendentes
/// (`pause_current`, split by the server into what was done and what is
/// left) and begins the card; a fixed block is not paused, and the card
/// begins after it. The server decides what that does to the rest of the
/// day — this only asks.
///
/// While it is open the timeline behind it is the one from before the drag.
/// Dismissing it therefore costs nothing: there is no move to undo, because
/// the move never happened.
/// {@endtemplate}
class GuardSheet extends StatelessWidget {
  /// {@macro guard_sheet}
  const GuardSheet({required this.guard, required this.busy, super.key});

  /// The question the server asked.
  final StartNowGuard guard;

  /// Whether the last answer is still in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tapping the dimmed timeline is the same as cancelling, which is
        // what a sheet over a screen already means everywhere else.
        Positioned.fill(
          child: GestureDetector(
            onTap: () =>
                context.read<TimelineBloc>().add(const GuardDismissed()),
            child: ColoredBox(color: AppColors.bg.withValues(alpha: 0.72)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (context) {
              final bloc = context.read<TimelineBloc>();
              final current = bloc.state.byId(guard.currentId);
              return PauseQuestion(
                current: guard.currentTitle,
                fixedUntil: current != null && !current.isTask
                    ? guard.currentEnd
                    : null,
                busy: busy,
                onAnswer: (yes) => bloc.add(
                  yes
                      ? const GuardAnswered(TimingDecision.pauseCurrent)
                      : const GuardDismissed(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
