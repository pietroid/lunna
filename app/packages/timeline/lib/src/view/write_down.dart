import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';

/// Opens the creation sheet and puts what it comes back with on the day.
///
/// Everything is flexible unless the user says fixed. Where a flexible one
/// goes is [placement]: anchored at an hour, which the sheet opens on and the
/// user can change; a place in the queue; or the backlog. The + at the foot
/// of the app passes wherever the day on screen is looking, a tap on empty
/// room the hour it tapped (and, when the room is short, its whole length),
/// and a + at the end of a section that section.
/// Fixed is an event, at its hour.
Future<void> writeDownOnTimeline(
  BuildContext context, {
  Placement placement = const Placement.backlog(),
  String? artifactId,
}) async {
  final bloc = context.read<TimelineBloc>();
  final l10n = context.l10n;
  final at = placement.at;
  final minutes = placement.minutes;
  final result = await AppPromptSheet.show(
    context,
    // The hour a block switched to fixed starts at, when it had none. It
    // comes off the cards already on screen rather than out of a request per
    // keystroke.
    previewFor: (duration) => TimelinePlan.nextQueuedStart(
      bloc.state.cards,
      bloc.state.tasks,
      duration,
      workDay: bloc.state.workDay,
    ),
    flexibleLabel: placement.backlog
        ? l10n.promptToBacklog
        : l10n.promptToQueue,
    initialStart: at,
    initialDuration: minutes == null ? null : Duration(minutes: minutes),
    // An artifact holds tasks; a fixed block is the calendar's alone.
    fixable: artifactId == null,
  );
  if (result == null) return;

  bloc.add(
    EventCreated(
      title: result.text,
      durationMinutes: result.duration.inMinutes,
      fixed: result.fixed,
      startTime: result.startTime,
      placement: placement,
      artifactId: artifactId,
    ),
  );
}
