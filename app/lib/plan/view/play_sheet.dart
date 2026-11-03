import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:timeline/timeline.dart';

/// Above this, play asks how much first.
const kPlayAsksOver = 60;

/// The pieces the sheet offers, in minutes.
const kPlayPieces = [30, 60];

/// What the person answered to [PlaySheet].
sealed class PlayChoice {
  const PlayChoice();
}

/// A piece of a task with no tasks of its own: a task of [minutes] is
/// written into it and begun, so the piece is on Agora and in the task.
final class PlayPiece extends PlayChoice {
  /// A piece of [minutes].
  const PlayPiece(this.minutes);

  /// How long the piece is.
  final int minutes;
}

/// The whole of it: its next task, or all it still owes, with no new task.
final class PlayWhole extends PlayChoice {
  /// The whole.
  const PlayWhole();
}

/// Talk it over with the agent instead.
final class PlayTalk extends PlayChoice {
  /// Talk.
  const PlayTalk();
}

/// Plays a pending task, asking first when what would begin runs over an
/// hour ([kPlayAsksOver]):
///
/// - with tasks of its own, its next task: the sheet asks to confirm it;
/// - without, what it still owes: the sheet offers 30 min, 1 h or all of
///   it, and a piece is written into it as a task of its own.
///
/// An hour or less begins at once. Either way the begin is a drop on
/// Agora, so the guard still asks when something else runs. *Falar com a
/// Lunna* opens the conversation about it instead.
Future<void> playPending(BuildContext context, Artifact artifact) async {
  final bloc = context.read<TimelineBloc>();
  if (!playAsks(artifact)) {
    bloc.add(ArtifactPlayed(artifact.id));
    return;
  }
  final choice = await PlaySheet.show(context, PlaySheet(artifact: artifact));
  if (!context.mounted) return;
  switch (choice) {
    case null:
      return;
    case PlayWhole():
      bloc.add(ArtifactPlayed(artifact.id));
    case PlayPiece(:final minutes):
      bloc.add(ArtifactPlayed(artifact.id, minutes: minutes));
    case PlayTalk():
      await showAgentSheet(context, about: AgentSubject.artifact(artifact.id));
  }
}

/// Whether play on [artifact] asks first: what would begin, its next task
/// or (with none) all it still owes, is over [kPlayAsksOver].
bool playAsks(Artifact artifact) {
  final next = nextTaskOf(artifact);
  final length = next?.minutes ?? artifact.minutes - artifact.doneMinutes;
  return length > kPlayAsksOver;
}

/// Whether play on [card], a loose task with an hour or in the backlog,
/// asks first: it has not begun and is over [kPlayAsksOver].
bool playCardAsks(TimelineEvent card) =>
    card.isTask &&
    !card.started &&
    card.artifactId == null &&
    card.workMinutes > kPlayAsksOver;

/// {@template play_sheet}
/// How much of a task to begin, asked when it is over an hour, wherever
/// its play is (Em seguida, Pendentes, Para depois, the calendar).
///
/// With no tasks of its own: 30 min, 1 h or all of it (*Tudo · 2h30*), the
/// pieces in a row, and *Falar com a Lunna* under them. A delivery's piece
/// becomes a task inside it; a loose task's piece begins and the rest
/// waits in Pendentes. With tasks, it names the next one and asks to begin
/// it (*Começar*), or talk.
/// {@endtemplate}
class PlaySheet extends StatelessWidget {
  /// {@macro play_sheet}
  const PlaySheet({required Artifact this.artifact, super.key}) : card = null;

  /// The sheet for a loose task, [card].
  const PlaySheet.task({required TimelineEvent this.card, super.key})
    : artifact = null;

  /// The task with tasks of its own, when it is one.
  final Artifact? artifact;

  /// The loose task, when it is one.
  final TimelineEvent? card;

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
    final a = artifact;
    final next = a == null ? null : nextTaskOf(a);
    final title = a?.title ?? card!.title;
    final owed = a == null ? card!.workMinutes : a.minutes - a.doneMinutes;
    void pick(PlayChoice choice) => Navigator.of(context).pop(choice);

    final talk = AppButton(
      text: l10n.notificationActionTalk(AppBrand.id),
      variant: AppButtonVariant.secondary,
      expand: true,
      onPressed: () => pick(const PlayTalk()),
    );

    final List<Widget> body;
    if (next != null) {
      body = [
        Text(l10n.playNextTitle(next.title), style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.playNextBody(title, formatMinutes(l10n, next.minutes)),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          text: l10n.playNextStart,
          expand: true,
          onPressed: () => pick(const PlayWhole()),
        ),
        const SizedBox(height: AppSpacing.s2),
        talk,
      ];
    } else {
      body = [
        Text(l10n.playPieceTitle, style: AppTypography.title),
        const SizedBox(height: AppSpacing.s1),
        Text(
          a == null
              ? l10n.playPieceBodyLoose(title, formatMinutes(l10n, owed))
              : l10n.playPieceBody(title, formatMinutes(l10n, owed)),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpacing.s5),
        Row(
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
                  onPressed: () => pick(PlayPiece(minutes)),
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
                onPressed: () => pick(const PlayWhole()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        talk,
      ];
    }

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
              ...body,
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: l10n.commonCancel,
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
