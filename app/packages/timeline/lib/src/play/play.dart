import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/format.dart';

/// Play by strict rules (#89): **when**, then (with something running) the
/// **pause**, then **how much**, each one sheet, and the move posted once,
/// after the last answer. Plano, the calendar and a delivery's page all
/// play through here, and so do their drops: a drop has answered *when* by
/// where it was let go.

/// Above this, play asks how much.
const kPlayAsksOver = 60;

/// The pieces the how-much question offers under the most, in minutes.
const kPlayPieces = [30, 60];

/// The least room worth offering: an hour with less is never suggested,
/// or the how-much question would have nothing to offer.
const kPlayMinRoom = 20;

/// What the how-much question offers for a task that still owes [owed]
/// minutes, at an hour with [room] minutes free until what comes next;
/// null when it asks nothing (an hour or less, and it fits).
///
/// - Over an hour: 30 min, 1 h, and the whole when it fits, else all the
///   room there is; under an hour of room, only that room.
/// - An hour or less that does not fit: only the room.
List<int>? playPieces({required int owed, required int room}) {
  if (owed <= kPlayAsksOver) return owed <= room ? null : [room];
  if (room < kPlayAsksOver) return [room];
  final most = room >= owed ? owed : room;
  return [...kPlayPieces.where((m) => m < most), most];
}

/// {@template play_room}
/// The room at an hour: the minutes from [at] to the next thing that does
/// not move ([until]: an event, a task that keeps its hour, a begun task's
/// hour) less the pause, or to the end of the working day ([until] null,
/// [end] its hour). Queued tasks flow around whatever is put there, so
/// they take none of it.
/// {@endtemplate}
class PlayRoom {
  /// {@macro play_room}
  const PlayRoom({
    required this.at,
    required this.minutes,
    required this.end,
    this.until,
  });

  /// Where it is measured from.
  final DateTime at;

  /// How many minutes there are.
  final int minutes;

  /// What bounds it, or null for the end of the working day.
  final TimelineEvent? until;

  /// The hour that bounds it: [until]'s start, or the day's end.
  final DateTime end;

  /// What the room runs up to, as the how-much question says it.
  String untilLabel(AppLocalizations l10n) {
    final next = until;
    return next == null
        ? l10n.playMuchDayEnd(hhmm(end))
        : l10n.playMuchUntil(next.title, hhmm(next.startTime));
  }
}

/// What runs on Agora now, other than [id]: a begun task or an event.
TimelineEvent? playRunning(TimelineState day, {String? id, DateTime? now}) {
  final at = now ?? clock.now();
  return day.cards
      .where(
        (c) =>
            c.id != id &&
            c.section == TimelineSection.agora &&
            (c.started || !c.isTask) &&
            c.endTime.isAfter(at),
      )
      .firstOrNull;
}

/// Everything on the day that does not move for task [id]: events, begun
/// tasks and tasks that keep an hour. With [pausing], what runs is left
/// out, as the pause takes it off the day.
List<TimelineEvent> _obstacles(
  TimelineState day,
  DateTime at, {
  String? id,
  bool pausing = false,
}) {
  final running = pausing ? playRunning(day, id: id, now: at) : null;
  return [
    for (final c in day.cards)
      if (c.id != id &&
          !(running != null && running.isTask && c.id == running.id) &&
          (!c.isTask || c.started || c.keepsHour))
        c,
  ];
}

DateTime _toMinute(DateTime at) =>
    DateTime(at.year, at.month, at.day, at.hour, at.minute);

/// The room at [at] for task [id] ([PlayRoom]); none outside the working
/// day, or inside something that does not move.
PlayRoom playRoomAt(
  TimelineState day,
  DateTime at, {
  String? id,
  bool pausing = false,
}) {
  final from = _toMinute(at);
  final dayEnd = day.workDay.endOn(from);
  if (from.isBefore(day.workDay.startOn(from)) || !from.isBefore(dayEnd)) {
    return PlayRoom(at: from, minutes: 0, end: from);
  }
  final obstacles = _obstacles(day, from, id: id, pausing: pausing);
  if (obstacles.any(
    (c) => !c.startTime.isAfter(from) && c.endTime.isAfter(from),
  )) {
    return PlayRoom(at: from, minutes: 0, end: from);
  }
  final next =
      (obstacles.where((c) => c.startTime.isAfter(from)).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime)))
          .firstOrNull;
  if (next == null || !next.startTime.isBefore(dayEnd)) {
    return PlayRoom(
      at: from,
      minutes: dayEnd.difference(from).inMinutes,
      end: dayEnd,
    );
  }
  final minutes = next.startTime
      .subtract(TimelinePlan.gap)
      .difference(from)
      .inMinutes;
  return PlayRoom(
    at: from,
    minutes: minutes < 0 ? 0 : minutes,
    end: next.startTime,
    until: next,
  );
}

/// The first hour from [from] with [kPlayMinRoom] of room for task [id]:
/// rule 3, so the how-much question always has something to offer.
DateTime playFirstRoom(
  TimelineState day,
  DateTime from, {
  String? id,
  bool pausing = false,
}) {
  var at = _toMinute(from);
  final obstacles = _obstacles(day, at, id: id, pausing: pausing);
  for (var attempt = 0; attempt < 200; attempt++) {
    at = TimelinePlan.nextFreeStart(
      obstacles,
      const Duration(minutes: kPlayMinRoom),
      now: at,
      workDay: day.workDay,
    );
    if (playRoomAt(day, at, id: id, pausing: pausing).minutes >= kPlayMinRoom) {
      return at;
    }
    at = at.add(TimelinePlan.gap);
  }
  return at;
}

/// The place in the list of tasks that is first in Em seguida: right
/// after the task running on Agora, else the top.
int nextIndexOf(TimelineState day) {
  final running = day.tasks.firstOrNull;
  return running != null && running.started ? 1 : 0;
}

/// What play was answered when.
sealed class PlayChoice {
  const PlayChoice();
}

/// Begin it now.
final class PlayNow extends PlayChoice {
  /// Now.
  const PlayNow();
}

/// The later hour the when question offered.
final class PlayNext extends PlayChoice {
  /// Later.
  const PlayNext();
}

/// How much was answered: a piece of `minutes`, or null for the whole.
typedef PlayAmount = ({int? minutes});

/// What the when question offers: whether *Começar agora* is there, which
/// later hour, if any, and what runs.
typedef PlayWhen = ({
  bool canStartNow,
  PlayLater? later,
  DateTime? laterAt,
  TimelineEvent? running,
});

/// What the when question offers for [card] at [now] ([PlayWhen]).
PlayWhen playWhenOf(TimelineState day, TimelineEvent card, {DateTime? now}) {
  final at = _toMinute(now ?? clock.now());
  final running = playRunning(day, id: card.id, now: at);
  // A fixed block running leaves no room now: it is not paused.
  final canStartNow =
      (running == null || running.isTask) &&
      playRoomAt(day, at, id: card.id, pausing: true).minutes >= kPlayMinRoom;

  if (running == null) {
    final soon = at.add(const Duration(minutes: 15));
    if (playRoomAt(day, soon, id: card.id).minutes >= kPlayMinRoom) {
      return (
        canStartNow: canStartNow,
        later: PlayLater.soon,
        laterAt: soon,
        running: null,
      );
    }
    return (
      canStartNow: canStartNow,
      later: PlayLater.at,
      laterAt: playFirstRoom(day, soon, id: card.id),
      running: null,
    );
  }

  // Next already: there is no later hour to offer.
  if (day.tasks.elementAtOrNull(nextIndexOf(day))?.id == card.id) {
    return (
      canStartNow: canStartNow,
      later: null,
      laterAt: null,
      running: running,
    );
  }
  return (
    canStartNow: canStartNow,
    later: PlayLater.after,
    laterAt: playFirstRoom(
      day,
      running.endTime.add(TimelinePlan.gap),
      id: card.id,
    ),
    running: running,
  );
}

/// Plays [card], a task that waits (#89): **when** ([PlayWhenQuestion]),
/// then, now, what [beginTask] asks; later, how much goes to that hour
/// ([askHowMuch]). A task already waiting on Agora is next already: it
/// begins ([beginTask]).
Future<void> playTask(BuildContext context, TimelineEvent card) async {
  if (card.section == TimelineSection.agora) {
    return beginTask(context, card);
  }
  final bloc = context.read<TimelineBloc>();
  final day = bloc.state;
  final when = playWhenOf(day, card);
  final running = when.running;
  final choice = await showPlaySheet<PlayChoice>(
    context,
    PlayWhenQuestion(
      title: card.title,
      owed: card.workMinutes,
      later: when.later,
      laterAt: when.laterAt,
      running: running?.title,
      runningEnd: running?.endTime,
      canStartNow: when.canStartNow,
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case null:
      return;
    case PlayNow():
      return beginTask(context, card);
    case PlayNext():
      final at = when.laterAt!;
      final amount = await askHowMuch(context, card, at: at);
      if (amount == null) return;
      // Right after what runs, where the queue would put it anyway, is a
      // place; any other hour is an anchor.
      final natural =
          running != null &&
          _toMinute(running.endTime.add(TimelinePlan.gap)) == at;
      bloc.add(
        EventMoved(
          id: card.id,
          index: nextIndexOf(day),
          after: natural ? null : at,
          minutes: amount.minutes,
          split: amount.minutes != null,
        ),
      );
  }
}

/// Begins [card] now, as a drop on Agora does (#89): with a task running,
/// first whether to pause it ([PauseQuestion]), then how much fits from
/// now ([askHowMuch]), and the move is posted once, carrying the answer,
/// so the server raises no guard. A fixed block running is not paused:
/// the move goes as it is, and the server asks.
Future<void> beginTask(BuildContext context, TimelineEvent card) async {
  final bloc = context.read<TimelineBloc>();
  final running = playRunning(bloc.state, id: card.id);
  final pausing = running != null && running.isTask;
  if (pausing) {
    final yes = await showPlaySheet<bool>(
      context,
      PauseQuestion(current: running.title),
    );
    if (yes != true || !context.mounted) return;
  }
  int? minutes;
  if (running == null || pausing) {
    final amount = await askHowMuch(context, card, pausing: pausing);
    if (amount == null) return;
    minutes = amount.minutes;
  }
  bloc.add(
    EventMoved(
      id: card.id,
      index: 0,
      start: true,
      minutes: minutes,
      decision: pausing ? TimingDecision.pauseCurrent : null,
    ),
  );
}

/// How much of [card] goes to [at] (now when null), measured against the
/// room there ([playRoomAt]); answers at once, without a sheet, when
/// [playPieces] asks nothing. Null when the sheet was dismissed.
Future<PlayAmount?> askHowMuch(
  BuildContext context,
  TimelineEvent card, {
  DateTime? at,
  bool pausing = false,
}) async {
  final day = context.read<TimelineBloc>().state;
  final room = playRoomAt(
    day,
    at ?? clock.now(),
    id: card.id,
    pausing: pausing,
  );
  final owed = card.workMinutes;
  // A begun task owes what it owes, whole; under five minutes there is no
  // piece worth cutting, and the server has the last word.
  if (card.started || room.minutes < 5) return (minutes: null);
  final pieces = playPieces(owed: owed, room: room.minutes);
  if (pieces == null) return (minutes: null);
  return showPlaySheet<PlayAmount>(
    context,
    PlayMuchQuestion(
      title: card.title,
      owed: owed,
      room: room.minutes,
      until: room.untilLabel(context.l10n),
      at: at,
    ),
  );
}

/// Opens one of play's questions as a modal sheet over [context].
Future<T?> showPlaySheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

/// Which later hour [PlayWhenQuestion] offers beside *Começar agora*.
enum PlayLater {
  /// Nothing runs: 15 minutes from now.
  soon,

  /// Nothing runs, and 15 minutes from now has under [kPlayMinRoom] of
  /// room: the first hour that has.
  at,

  /// Something runs: right after it, at the first hour with room.
  after,
}

/// {@template play_when_question}
/// Play's first question (#89): **when**. *Começar agora* (the accent,
/// gone when now has under [kPlayMinRoom] of room) and one later hour:
/// 15 minutes from now when nothing runs ([PlayLater.soon]), the first
/// hour with room when that has none ([PlayLater.at]), or right after
/// what runs ([PlayLater.after]); none when the task is next already.
/// The hour is where it begins, whether or not it all fits: the second
/// question asks how much.
/// {@endtemplate}
class PlayWhenQuestion extends StatelessWidget {
  /// {@macro play_when_question}
  const PlayWhenQuestion({
    required this.title,
    required this.owed,
    required this.later,
    required this.laterAt,
    this.running,
    this.runningEnd,
    this.canStartNow = true,
    super.key,
  });

  /// The task.
  final String title;

  /// What it still asks, in minutes.
  final int owed;

  /// Which later hour, or null for none.
  final PlayLater? later;

  /// That hour.
  final DateTime? laterAt;

  /// What runs now, if anything.
  final String? running;

  /// When [running] ends.
  final DateTime? runningEnd;

  /// Whether now has [kPlayMinRoom] of room.
  final bool canStartNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = durationLabel(l10n, owed);
    final at = laterAt == null ? '' : hhmm(laterAt!);
    final laterText = switch (later) {
      PlayLater.soon => l10n.playWhenSoon(at),
      PlayLater.at => l10n.playWhenAt(at),
      PlayLater.after => l10n.playWhenAfter(running ?? '', at),
      null => null,
    };
    return PlaySheetFrame(
      children: [
        Text(l10n.playWhenTitle(title), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          running == null || runningEnd == null
              ? l10n.playWhenIdle(length)
              : l10n.playWhenBusy(running!, hhmm(runningEnd!), length),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        if (canStartNow)
          AppButton(
            text: l10n.playWhenNow,
            expand: true,
            onPressed: () => Navigator.of(context).pop(const PlayNow()),
          ),
        if (canStartNow && laterText != null)
          const SizedBox(height: AppSpacing.s2),
        if (laterText != null)
          AppButton(
            text: laterText,
            variant: canStartNow
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(const PlayNext()),
          ),
      ],
    );
  }
}

/// {@template play_much_question}
/// Play's second question (#89): **how much**, measured against the room
/// at the hour the first answer chose ([at], null for now) up to what
/// comes next ([until]). The pieces are [playPieces]'s; a piece splits
/// the task in two subtasks, the piece and the rest. Answers a
/// [PlayAmount].
/// {@endtemplate}
class PlayMuchQuestion extends StatelessWidget {
  /// {@macro play_much_question}
  const PlayMuchQuestion({
    required this.title,
    required this.owed,
    required this.room,
    required this.until,
    this.at,
    super.key,
  });

  /// The task (or subtask) that begins.
  final String title;

  /// What it still asks, in minutes.
  final int owed;

  /// The minutes free from its hour to [until].
  final int room;

  /// What the room runs up to (`playMuchUntil`, `playMuchDayEnd`).
  final String until;

  /// The hour it goes to, or null for now.
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pieces = playPieces(owed: owed, room: room) ?? [owed];
    final length = durationLabel(l10n, owed);
    void pick(int minutes) => Navigator.of(
      context,
    ).pop<PlayAmount>((minutes: minutes >= owed ? null : minutes));

    if (pieces.length == 1) {
      final only = durationLabel(l10n, pieces.single);
      return PlaySheetFrame(
        children: [
          Text(
            l10n.playMuchShortTitle(only, until),
            style: AppTypography.title,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            l10n.playMuchShortBody(
              title,
              length,
              only,
              durationLabel(l10n, owed - pieces.single),
            ),
            style: AppTypography.body.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: l10n.playMuchDo(only),
            expand: true,
            onPressed: () => pick(pieces.single),
          ),
        ],
      );
    }

    return PlaySheetFrame(
      children: [
        Text(
          at == null ? l10n.playMuchNowTitle : l10n.playMuchAtTitle(hhmm(at!)),
          style: AppTypography.title,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          [
            l10n.playMuchRoomUntil(
              title,
              length,
              durationLabel(l10n, room),
              until,
            ),
            if (at == null) l10n.playMuchRestNow else l10n.playMuchRestStays,
          ].join(' '),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        Row(
          children: [
            for (final (i, minutes) in pieces.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.s2),
              Expanded(
                flex: i == pieces.length - 1 ? 3 : 2,
                child: AppButton(
                  text: minutes == owed
                      ? l10n.playWhole(length)
                      : durationLabel(l10n, minutes),
                  // The smallest piece is the one offered.
                  variant: i == 0
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => pick(minutes),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// {@template pause_question}
/// The guard after *Começar agora* while a task runs (#89): one yes or
/// no, saying only that [current] goes to Pendentes. Yes (`true`) pauses
/// it there (split by the server in two subtasks, the minutes done and
/// the ones left) and begins what was played; no changes nothing.
/// {@endtemplate}
class PauseQuestion extends StatelessWidget {
  /// {@macro pause_question}
  const PauseQuestion({
    required this.current,
    this.fixedUntil,
    this.onAnswer,
    this.busy = false,
    super.key,
  });

  /// What runs, and is paused.
  final String current;

  /// When what runs is a fixed block, its end: it is not paused, and what
  /// was played begins after it.
  final DateTime? fixedUntil;

  /// Answers in place, for the guard drawn over a page; by default the
  /// answer pops the sheet.
  final ValueChanged<bool>? onAnswer;

  /// Whether the answer is still in flight (the guard's).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void answer({required bool yes}) {
      if (busy) return;
      final on = onAnswer;
      if (on != null) return on(yes);
      Navigator.of(context).pop(yes);
    }

    return PlaySheetFrame(
      cancel: false,
      children: [
        Text(
          fixedUntil == null
              ? l10n.guardPauseTitle(current)
              : l10n.guardWaitTitle(current),
          style: AppTypography.title,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          fixedUntil == null
              ? l10n.guardPauseBody(current)
              : l10n.guardWaitBody(current, hhmm(fixedUntil!)),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        Opacity(
          opacity: busy ? 0.5 : 1,
          child: AppButton(
            text: fixedUntil == null ? l10n.guardPauseYes : l10n.guardWaitYes,
            expand: true,
            onPressed: () => answer(yes: true),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        AppButton.text(
          text: l10n.guardPauseNo,
          color: AppColors.ink2,
          expand: true,
          onPressed: () => answer(yes: false),
        ),
      ],
    );
  }
}

/// {@template play_sheet_frame}
/// A play sheet's frame: the page's ground, its corners, and Cancelar at
/// its foot ([cancel]).
/// {@endtemplate}
class PlaySheetFrame extends StatelessWidget {
  /// {@macro play_sheet_frame}
  const PlaySheetFrame({required this.children, this.cancel = true, super.key});

  /// What the sheet says and offers.
  final List<Widget> children;

  /// Whether Cancelar closes it at its foot.
  final bool cancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                AppSpacing.s5,
                AppSpacing.s6,
                AppSpacing.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (cancel) ...[
                    const SizedBox(height: AppSpacing.s2),
                    AppButton.text(
                      text: context.l10n.commonCancel,
                      color: AppColors.ink2,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
