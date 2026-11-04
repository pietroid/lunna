import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:timeline/timeline.dart';

/// Plays a task with tasks of its own (a delivery), as every play does
/// (#89), about what would begin: its next task, through [playTask], or
/// (with none) a piece of what it still owes, asked at now
/// ([PlayMuchQuestion]) and written into it by [ArtifactPlayed], which
/// the guard still asks about when something runs.
Future<void> playPending(BuildContext context, Artifact artifact) async {
  final bloc = context.read<TimelineBloc>();
  final day = bloc.state;
  final next = nextTaskOf(artifact);
  // Its next task, as the day draws it: queued, or in the backlog.
  final task = next == null ? null : day.byId(next.id);
  if (task != null) return playTask(context, task);
  if (next != null) return bloc.add(ArtifactPlayed(artifact.id));

  final left = artifact.minutes - artifact.doneMinutes;
  final owed = left > 0 ? left : 0;
  final room = playRoomAt(day, clock.now());
  final pieces = playPieces(owed: owed, room: room.minutes);
  int? minutes;
  if (pieces != null && room.minutes >= 5) {
    final amount = await showPlaySheet<PlayAmount>(
      context,
      PlayMuchQuestion(
        title: artifact.title,
        owed: owed,
        room: room.minutes,
        until: room.untilLabel(context.l10n),
      ),
    );
    if (amount == null) return;
    minutes = amount.minutes;
  }
  bloc.add(ArtifactPlayed(artifact.id, minutes: minutes));
}
