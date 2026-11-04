import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:timeline/timeline.dart';

/// Above this, play asks how much too.
const kPlayAsksOver = 60;

/// The pieces the sheets offer, in minutes.
const kPlayPieces = [30, 60];

/// What the person answered to a play sheet.
sealed class PlayChoice {
  const PlayChoice();
}

/// A piece of [minutes] of it.
final class PlayPiece extends PlayChoice {
  /// A piece of [minutes].
  const PlayPiece(this.minutes);

  /// How long the piece is.
  final int minutes;
}

/// The whole of it.
final class PlayWhole extends PlayChoice {
  /// The whole.
  const PlayWhole();
}

/// Begin it now ([PlayWhenSheet]).
final class PlayNow extends PlayChoice {
  /// Now.
  const PlayNow();
}

/// Put it first in Em seguida, at the next hour the day has room for
/// ([PlayWhenSheet]).
final class PlayNext extends PlayChoice {
  /// Later: next.
  const PlayNext();
}

/// Talk it over with the agent instead.
final class PlayTalk extends PlayChoice {
  /// Talk.
  const PlayTalk();
}

/// What play was answered: begun now (`now`) or queued first in Em
/// seguida, and the piece in `minutes`, or null for the whole.
typedef PlayAnswer = ({bool now, int? minutes});

/// Play's two questions, one sheet each (#87):
///
/// 1. **When** ([PlayWhenSheet]): *Começar agora* or *Em seguida · hh:mm*
///    ([nextAt]; null when there is nothing to queue, and then it asks
///    nothing and the answer is now).
/// 2. **How much**, only over an hour ([kPlayAsksOver]): before beginning
///    ([PlaySheet]), or for that hour of Em seguida ([PlaceSheet]).
///
/// Null when either sheet was dismissed. [onTalk] answers *Falar com a
/// Lunna* on the second.
Future<PlayAnswer?> askPlay(
  BuildContext context, {
  required String title,
  required int owed,
  required DateTime? nextAt,
  required String restBody,
  required Future<void> Function() onTalk,
  String? subtitle,
}) async {
  var now = true;
  if (nextAt != null) {
    final when = await PlayWhenSheet.show(
      context,
      PlayWhenSheet(
        title: title,
        subtitle: subtitle,
        owed: owed,
        nextAt: nextAt,
      ),
    );
    if (when is! PlayNow && when is! PlayNext) return null;
    now = when is PlayNow;
  }
  if (!context.mounted) return null;
  if (owed <= kPlayAsksOver) return (now: now, minutes: null);

  final much = now
      ? await PlaySheet.show(
          context,
          PlaySheet(title: title, owed: owed, body: restBody),
        )
      : await PlaceSheet.show(
          context,
          PlaceSheet(title: title, owed: owed, at: nextAt!),
        );
  if (!context.mounted) return null;
  switch (much) {
    case PlayPiece(:final minutes):
      return (now: now, minutes: minutes);
    case PlayWhole():
      return (now: now, minutes: null);
    case PlayTalk():
      await onTalk();
      return null;
    case null || PlayNow() || PlayNext():
      return null;
  }
}

/// Plays a task with tasks of its own (a delivery), as every play does
/// ([askPlay]), about what would begin: its next task, or (with none) a
/// piece of what it still owes.
///
/// - Now begins it, a drop on Agora, so the guard still asks when
///   something else runs. A piece of its next task begins and the rest
///   stays in the delivery; with no task, a piece is written into it.
/// - Em seguida puts its next task first in the queue, whole or a piece
///   ([queueFirst]). With no task left there is nothing to queue, and it
///   asks only how much.
Future<void> playPending(BuildContext context, Artifact artifact) async {
  final bloc = context.read<TimelineBloc>();
  final day = bloc.state;
  final next = nextTaskOf(artifact);
  // Its next task, as the day draws it: queued, or in the backlog.
  final task = next == null ? null : day.byId(next.id);
  final left = next?.minutes ?? artifact.minutes - artifact.doneMinutes;
  final owed = left > 0 ? left : 0;
  final title = next?.title ?? artifact.title;
  final answer = await askPlay(
    context,
    title: title,
    subtitle: next == null ? null : artifact.title,
    owed: owed,
    nextAt: task == null ? null : nextSlotOf(day, owed, id: task.id),
    restBody: context.l10n.placePieceBody(
      title,
      formatMinutes(context.l10n, owed),
    ),
    onTalk: () =>
        showAgentSheet(context, about: AgentSubject.artifact(artifact.id)),
  );
  switch (answer) {
    case null:
      return;
    case (now: true, :final minutes):
      bloc.add(
        task != null && minutes != null
            ? EventMoved(id: task.id, index: 0, start: true, minutes: minutes)
            : ArtifactPlayed(artifact.id, minutes: minutes),
      );
    case (now: false, :final minutes):
      if (task != null) bloc.add(queueFirst(day, task.id, minutes));
  }
}

/// Whether play on [card], a loose task with an hour or in the backlog,
/// asks how much before beginning: it has not begun and is over
/// [kPlayAsksOver].
bool playCardAsks(TimelineEvent card) =>
    card.isTask &&
    !card.started &&
    card.artifactId == null &&
    card.workMinutes > kPlayAsksOver;

/// {@template play_sheet}
/// How much to begin, the second question of play over an hour, and what
/// a loose task let go on Agora asks: 30 min (the accent), 1 h or all of
/// it (*Tudo · 2h30*), in a row, and *Falar com a Lunna* under them.
/// [body] says where the rest goes.
/// {@endtemplate}
class PlaySheet extends StatelessWidget {
  /// {@macro play_sheet}
  const PlaySheet({
    required this.title,
    required this.owed,
    required this.body,
    super.key,
  });

  /// The sheet for a loose task, [card]: the rest waits in Pendentes.
  PlaySheet.task({
    required TimelineEvent card,
    required AppLocalizations l10n,
    Key? key,
  }) : this(
         key: key,
         title: card.title,
         owed: card.workMinutes,
         body: l10n.playPieceBodyLoose(
           card.title,
           formatMinutes(l10n, card.workMinutes),
         ),
       );

  /// What begins.
  final String title;

  /// What it still asks, in minutes.
  final int owed;

  /// Under the title: how long it is and where the rest goes.
  final String body;

  /// Opens [sheet] over [context] and answers what was picked; null when
  /// it was dismissed.
  static Future<PlayChoice?> show(BuildContext context, PlaySheet sheet) {
    return showModalBottomSheet<PlayChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void pick(PlayChoice choice) => Navigator.of(context).pop(choice);

    return _SheetFrame(
      children: [
        Text(l10n.playPieceTitle, style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(body, style: AppTypography.body.copyWith(color: AppColors.ink2)),
        const SizedBox(height: AppSpacing.s5),
        _Pieces(owed: owed, onPick: pick),
        const SizedBox(height: AppSpacing.s2),
        AppButton(
          text: l10n.notificationActionTalk(AppBrand.id),
          variant: AppButtonVariant.secondary,
          expand: true,
          onPressed: () => pick(const PlayTalk()),
        ),
      ],
    );
  }
}

/// 30 min (the accent), 1 h and *Tudo*, in a row: what [PlaySheet] and
/// [PlaceSheet] offer.
class _Pieces extends StatelessWidget {
  const _Pieces({required this.owed, required this.onPick});

  final int owed;
  final ValueChanged<PlayChoice> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        for (final minutes in kPlayPieces) ...[
          Expanded(
            flex: 2,
            child: AppButton(
              text: formatMinutes(l10n, minutes),
              // The smallest piece is the one offered.
              variant: minutes == kPlayPieces.first
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              expand: true,
              onPressed: () => onPick(PlayPiece(minutes)),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
        Expanded(
          flex: 3,
          child: AppButton(
            text: l10n.playWhole(formatMinutes(l10n, owed)),
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: () => onPick(const PlayWhole()),
          ),
        ),
      ],
    );
  }
}

/// {@template play_when_sheet}
/// Play's first question, on every task that waits (#87): **when**, and
/// only that. *Começar agora* (the accent) begins it, raising the guard
/// as ever when something runs; *Em seguida · 11:40* puts it first in the
/// queue, at [nextAt], the next hour the day has room for it, and begins
/// nothing. How much is asked after, by a sheet of its own ([askPlay]).
/// {@endtemplate}
class PlayWhenSheet extends StatelessWidget {
  /// {@macro play_when_sheet}
  const PlayWhenSheet({
    required this.title,
    required this.owed,
    required this.nextAt,
    this.subtitle,
    super.key,
  });

  /// What begins: the task, or a delivery's next task.
  final String title;

  /// Under it: whose task it is, for a delivery's.
  final String? subtitle;

  /// What it still asks, in minutes.
  final int owed;

  /// Where Em seguida would put it.
  final DateTime nextAt;

  /// Shows [sheet] and answers with what was picked, or null.
  static Future<PlayChoice?> show(BuildContext context, PlayWhenSheet sheet) {
    return showModalBottomSheet<PlayChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void pick(PlayChoice choice) => Navigator.of(context).pop(choice);

    return _SheetFrame(
      children: [
        Text(l10n.playWhenTitle(title), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          [?subtitle, if (owed > 0) formatMinutes(l10n, owed)].join(' · '),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          text: l10n.playWhenNow,
          expand: true,
          onPressed: () => pick(const PlayNow()),
        ),
        const SizedBox(height: AppSpacing.s2),
        AppButton(
          text: l10n.playWhenNext(hhmm(nextAt)),
          variant: AppButtonVariant.secondary,
          expand: true,
          onPressed: () => pick(const PlayNext()),
        ),
      ],
    );
  }
}

/// {@template place_sheet}
/// How much goes to a place in Em seguida, at [at]: the second question of
/// play over an hour answered *Em seguida*, and what a task over an hour
/// let go in Em seguida asks. 30 min (the accent), 1 h or *Tudo*; the rest
/// stays where it was.
/// {@endtemplate}
class PlaceSheet extends StatelessWidget {
  /// {@macro place_sheet}
  const PlaceSheet({
    required this.title,
    required this.owed,
    required this.at,
    super.key,
  });

  /// The task.
  final String title;

  /// Its length, in minutes.
  final int owed;

  /// The hour of the place.
  final DateTime at;

  /// Shows [sheet] and answers with what was picked, or null.
  static Future<PlayChoice?> show(BuildContext context, PlaceSheet sheet) {
    return showModalBottomSheet<PlayChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void pick(PlayChoice choice) => Navigator.of(context).pop(choice);
    return _SheetFrame(
      children: [
        Text(l10n.placePieceTitle(hhmm(at)), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.placePieceBody(title, formatMinutes(l10n, owed)),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        _Pieces(owed: owed, onPick: pick),
      ],
    );
  }
}

/// A sheet's frame: the page's ground, its corners, and Cancelar at its
/// foot.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children, this.cancel = true});

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
    );
  }
}

// ---------------------------------------------------------------------------
// #89: play's questions by strict rules. The build replaces the sheets above
// with these and moves the arithmetic ([playPieces], the 20 minutes of room)
// next to the day's layout.
// ---------------------------------------------------------------------------

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

  /// What runs now, if anything, and when it ends.
  final String? running;

  /// When [running] ends.
  final DateTime? runningEnd;

  /// Whether now has [kPlayMinRoom] of room.
  final bool canStartNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = formatMinutes(l10n, owed);
    final at = laterAt == null ? '' : hhmm(laterAt!);
    final laterText = switch (later) {
      PlayLater.soon => l10n.playWhenSoon(at),
      PlayLater.at => l10n.playWhenAt(at),
      PlayLater.after => l10n.playWhenAfter(running ?? '', at),
      null => null,
    };
    return _SheetFrame(
      children: [
        Text(l10n.playWhenTitle(title), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          running == null
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
/// the task in two subtasks, the piece and the rest.
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
    final length = formatMinutes(l10n, owed);
    void pick(int minutes) => Navigator.of(context).pop(
      minutes == owed ? const PlayWhole() : PlayPiece(minutes),
    );

    if (pieces.length == 1) {
      final only = formatMinutes(l10n, pieces.single);
      return _SheetFrame(
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
              formatMinutes(l10n, owed - pieces.single),
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

    return _SheetFrame(
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
              formatMinutes(l10n, room),
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
                      : formatMinutes(l10n, minutes),
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
/// The guard after *Começar agora* while something runs (#89): one yes or
/// no, saying only that [current] goes to Pendentes. Yes pauses it there
/// (split in two subtasks, the minutes done and the ones left, by the
/// server) and begins what was played.
/// {@endtemplate}
class PauseQuestion extends StatelessWidget {
  /// {@macro pause_question}
  const PauseQuestion({
    required this.current,
    super.key,
  });

  /// What runs, and is paused.
  final String current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SheetFrame(
      cancel: false,
      children: [
        Text(l10n.guardPauseTitle(current), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.guardPauseBody(current),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          text: l10n.guardPauseYes,
          expand: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s2),
        AppButton.text(
          text: l10n.guardPauseNo,
          color: AppColors.ink2,
          expand: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
