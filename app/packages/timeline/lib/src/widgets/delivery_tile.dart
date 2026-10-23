import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/event_tile.dart';
import 'package:timeline/src/widgets/format.dart';
import 'package:timeline/src/widgets/now_surface.dart';

/// {@template delivery_tile}
/// A run of one delivery's tasks, drawn as one card: the delivery is the
/// title, and its tasks are under it.
///
/// Tasks of the same delivery that follow each other on the day are one
/// thing being worked on, and drawn so: the delivery's name once, in the
/// strong ink, with the hours of the whole run, in place of a card per task
/// each carrying the delivery as a tag. Only tasks next to each other are
/// joined, so the card never says anything about the order the day does not.
///
/// In Lista the card is short: under the name, only the next task, since
/// the hours on the right already say how much of the day the run takes.
///
/// With [timeline], and on the calendar ([height] given) when there is room
/// for them all, every task is a line with its hour, and on the calendar
/// the lines share the height by their lengths, so a long task reads as
/// long. Where they do not fit, the calendar falls back to the next task
/// alone. A run of one task has nothing to list, so the calendar shows it
/// as it shows any task: its title and the start of its notes.
///
/// In Agora the running task's line is the one in ink, the controls work on
/// it, and the card ends in one bar made of a piece per task, as long as
/// its time: the finished ones full, the running one as far as it has got.
///
/// A routine's day with a list of its own (breakfast: coffee, the dishes,
/// the plants) is drawn by the same card in the routine's fill ([routine]).
/// {@endtemplate}
class DeliveryTile extends StatelessWidget {
  /// {@macro delivery_tile}
  const DeliveryTile({
    required this.title,
    required this.tasks,
    this.done = const [],
    this.height,
    this.timeline = false,
    this.routine = false,
    this.onPauseToggled,
    this.onAdjusted,
    this.onDone,
    super.key,
  });

  /// The delivery's name.
  final String title;

  /// Its tasks in this run, in clock order. The first is the next one: the
  /// running one when the run is in Agora.
  final List<TimelineEvent> tasks;

  /// Its tasks already ticked off today, drawn first and quiet when every
  /// line is drawn, and full in Agora's bar.
  final List<TimelineEvent> done;

  /// The height the calendar gives it; null in Lista, where it is as tall
  /// as its lines.
  final double? height;

  /// Whether every task is drawn as a line, as the calendar draws a run
  /// that fits; otherwise only the next one is.
  final bool timeline;

  /// Whether this is a routine's day with a list, in the routine's fill.
  final bool routine;

  /// Pauses or resumes the running task.
  final VoidCallback? onPauseToggled;

  /// Fifteen minutes more or fewer for the running task.
  final ValueChanged<int>? onAdjusted;

  /// Ticks the running task off.
  final VoidCallback? onDone;

  bool get _isNow => tasks.first.section == TimelineSection.agora;

  TimelineEvent get _next => tasks.first;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(
            title: title,
            // The backlog has no hours, only how much is waiting.
            hours: _next.isBacklog
                ? context.l10n.deliveryTasks(
                    tasks.length,
                    durationLabel(
                      context.l10n,
                      tasks.fold(0, (sum, t) => sum + t.workMinutes),
                    ),
                  )
                : '${hhmm(_next.startTime)}–${hhmm(tasks.last.endTime)}',
            routine: routine,
          ),
          const SizedBox(height: AppSpacing.s1),
          if (height == null)
            if (timeline)
              for (final task in [...done, ...tasks]) _line(task)
            else
              _line(_next, hour: false)
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => _scaled(box.maxHeight),
              ),
            ),
          if (_isNow) ...[
            const SizedBox(height: AppSpacing.s2),
            _NowLine(
              card: _next,
              trailing: onAdjusted == null
                  ? null
                  : EventControls(
                      card: _next,
                      onPauseToggled: onPauseToggled,
                      onAdjusted: onAdjusted!,
                      onDone: onDone,
                    ),
            ),
            const SizedBox(height: AppSpacing.s2),
            RunBar(done: done, tasks: tasks),
          ],
        ],
      ),
    );

    final card = Material(
      type: _isNow ? MaterialType.transparency : MaterialType.canvas,
      color: _isNow
          ? null
          : routine
          ? AppColors.routineFill
          : AppColors.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: _isNow ? NowSurface(paused: _next.isPaused, child: body) : body,
    );

    final h = height;
    return h == null ? card : SizedBox(height: h, child: card);
  }

  Widget _line(TimelineEvent task, {bool hour = true}) => _Line(
    card: task,
    done: done.contains(task),
    running: _isNow && task == _next,
    routine: routine,
    hour: hour,
  );

  /// The calendar's [room] under the name: every task as a line spaced by
  /// its length when each gets a line's height, the next task alone when
  /// not, and a lone task with the start of its notes.
  Widget _scaled(double room) {
    final all = [...done, ...tasks];
    if (room < _Line.height) return const SizedBox.shrink();

    if (all.length == 1) {
      final notes = notesPreview(_next.notes);
      final lines = ((room - _Line.height) / _notesLine).floor().clamp(0, 3);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(_next, hour: false),
          if (notes.isNotEmpty && lines > 0)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s6),
              child: Text(
                notes,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: AppColors.ink2),
              ),
            ),
        ],
      );
    }

    if (all.length * _Line.height > room) return _line(_next, hour: false);

    // Each line where its hour falls in the run, pushed down when the one
    // above needs the room, and up when the ones below would not fit.
    final start = all.first.startTime;
    final span = all.last.endTime.difference(start).inMinutes;
    final tops = <double>[];
    for (final (i, task) in all.indexed) {
      final at = room * task.startTime.difference(start).inMinutes / span;
      final below = room - (all.length - i) * _Line.height;
      final above = i == 0 ? 0.0 : tops.last + _Line.height;
      tops.add(math.min(math.max(at, above), below));
    }

    return Stack(
      children: [
        for (final (i, task) in all.indexed)
          Positioned(
            top: tops[i],
            left: 0,
            right: 0,
            child: _line(task),
          ),
      ],
    );
  }

  /// The height of a line of notes in the caption style.
  static const double _notesLine = 18;
}

/// The delivery's name and the hours of the whole run.
class _Head extends StatelessWidget {
  const _Head({
    required this.title,
    required this.hours,
    required this.routine,
  });

  final String title;
  final String hours;
  final bool routine;

  @override
  Widget build(BuildContext context) {
    final quiet = routine ? AppColors.routineInk : AppColors.ink3;
    return Row(
      children: [
        AppIcon(
          iconData: routine ? AppIcons.repeat : AppIcons.artifacts,
          size: AppSpacing.s4,
          color: quiet,
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Text(hours, style: AppTypography.label.copyWith(color: quiet)),
      ],
    );
  }
}

/// One task of the run: a mark, its title and its hour.
///
/// The mark says where it is: a check when done, a full dot while it runs,
/// a ring while it waits.
class _Line extends StatelessWidget {
  const _Line({
    required this.card,
    required this.done,
    required this.running,
    required this.routine,
    this.hour = true,
  });

  /// The height of one line.
  static const double height = 28;

  final TimelineEvent card;
  final bool done;
  final bool running;
  final bool routine;

  /// Whether its hour is drawn at the end: not when it is the only line,
  /// under the run's own hours.
  final bool hour;

  @override
  Widget build(BuildContext context) {
    final quiet = routine ? AppColors.routineInk : AppColors.ink3;
    final ink = done
        ? quiet
        : running
        ? AppColors.ink
        : AppColors.ink2;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.s4,
            child: Center(
              child: done
                  ? AppIcon(iconData: AppIcons.check, size: 14, color: quiet)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: running ? AppColors.accent : null,
                        border: running
                            ? null
                            : Border.all(color: quiet, width: 1.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              card.title,
              style: AppTypography.label.copyWith(
                color: ink,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: quiet,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hour) ...[
            const SizedBox(width: AppSpacing.s3),
            Text(
              done || card.isBacklog
                  ? durationLabel(context.l10n, card.workMinutes)
                  : hhmm(card.startTime),
              style: AppTypography.caption.copyWith(color: quiet),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Faltam 22 min" for the running task, with the controls at its end.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.card, this.trailing});

  final TimelineEvent card;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progress = card.progressAt(clock.now());
    final left = (card.workMinutes * (1 - progress)).ceil();
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: Text(
            card.isPaused
                ? l10n.nowPausedLeft(durationLabel(l10n, left))
                : l10n.nowLeft(durationLabel(l10n, left)),
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// {@template run_bar}
/// One bar for a run of tasks: a piece per task, as long as its time, with
/// a hair of room between them. The finished pieces are full, the running
/// one as far as it has got, the rest empty.
/// {@endtemplate}
class RunBar extends StatelessWidget {
  /// {@macro run_bar}
  const RunBar({required this.tasks, this.done = const [], super.key});

  /// The tasks still to finish, the running one first.
  final List<TimelineEvent> tasks;

  /// The tasks already finished, drawn full before them.
  final List<TimelineEvent> done;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final running = tasks.first;
    final paused = running.isPaused;

    double filled(TimelineEvent task) {
      if (done.contains(task)) return 1;
      if (task != running) return 0;
      return running.progressAt(now);
    }

    final all = [...done, ...tasks];
    return SizedBox(
      height: 3,
      child: Row(
        children: [
          for (final (i, task) in all.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: task.workMinutes,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                child: LinearProgressIndicator(
                  value: filled(task),
                  minHeight: 3,
                  backgroundColor: AppColors.line,
                  color: paused && task == running
                      ? AppColors.ink3
                      : AppColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
