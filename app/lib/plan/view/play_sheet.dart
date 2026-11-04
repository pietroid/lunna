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
  const _SheetFrame({required this.children});

  final List<Widget> children;

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
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: context.l10n.commonCancel,
                color: AppColors.ink2,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
