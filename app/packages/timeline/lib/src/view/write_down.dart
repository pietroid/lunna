import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/free_stretch.dart';

/// Opens the creation sheet and puts what it comes back with on the day.
///
/// Flexible is a task, at the end of the backlog, in whichever mode it was
/// written down: it gets an hour once it is dragged into the queue. Fixed is
/// an event, at its hour. The + button opens the sheet with nothing chosen.
/// A tap on empty room opens it from [tap]: fixed at the hour that was
/// tapped, or proposing the room's start should it be switched to fixed.
Future<void> writeDownOnTimeline(BuildContext context, {FreeTap? tap}) async {
  final bloc = context.read<TimelineBloc>();
  final floor = tap?.from;
  final result = await AppPromptSheet.show(
    context,
    // The hour a block switched to fixed starts at. It comes off the cards
    // already on screen rather than out of a request per keystroke.
    previewFor: (duration) => floor == null
        ? TimelinePlan.nextQueuedStart(
            bloc.state.cards,
            bloc.state.tasks,
            duration,
          )
        : TimelinePlan.nextFreeStart(bloc.state.cards, duration, now: floor),
    flexibleLabel: context.l10n.promptToBacklog,
    initialStart: tap?.fixedAt,
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
