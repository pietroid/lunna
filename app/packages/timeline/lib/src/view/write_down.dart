import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/free_stretch.dart';

/// Opens the creation sheet and puts what it comes back with on the day.
///
/// The + button opens it with nothing chosen. A tap on empty room opens it
/// from [tap]: fixed at the hour that was tapped, or flexible and looking for
/// room no earlier than the room that was tapped.
Future<void> writeDownOnTimeline(BuildContext context, {FreeTap? tap}) async {
  final bloc = context.read<TimelineBloc>();
  // The room it was written down in, flexible or not, so switching a fixed
  // one to flexible still looks for a slot there.
  final floor = tap?.from;
  final result = await AppPromptSheet.show(
    context,
    // The sheet asks where something would land while the user is still
    // typing, so the answer comes off the cards already on screen rather
    // than out of a request per keystroke.
    previewFor: (duration) =>
        TimelinePlan.nextFreeStart(bloc.state.cards, duration, now: floor),
    initialStart: tap?.fixedAt,
  );
  if (result == null) return;

  bloc.add(
    EventCreated(
      title: result.text,
      durationMinutes: result.duration.inMinutes,
      fixed: result.fixed,
      startTime: result.startTime,
      notBefore: result.fixed ? null : floor,
    ),
  );
}
