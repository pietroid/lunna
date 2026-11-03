import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/confirm_sheet.dart';
import 'package:timeline/src/widgets/event_tile.dart';
import 'package:timeline/src/widgets/format.dart';
import 'package:timeline/src/widgets/now_surface.dart';

/// The bar under a [TaskCard]: how much of its work is done and, when it
/// is owed by a day, how much of its time has gone.
class TaskBar {
  /// Work done, 0 to 1, over [time] gone, 0 to 1. Without [time] the bar is
  /// Agora's: one fill, the accent, the block's own minutes.
  const TaskBar({required this.done, this.time, this.late = false});

  /// The work done, 0 to 1.
  final double done;

  /// The time gone from its start to its day, 0 to 1; null when it is owed
  /// by no day, or for the running block.
  final double? time;

  /// Whether its day has gone by: the time runs the whole bar, red, with
  /// the work done still over it.
  final bool late;
}

/// What −/+ on a [TaskCard] step by: ten minutes of its length (Agora),
/// or a day of its deadline (Pendentes).
enum TaskStep {
  /// −10 and +10, the length.
  minutes,

  /// −1d and +1d, the day it is due by.
  days,
}

/// {@template task_card}
/// One task, drawn the same way wherever it appears: on the Plano's
/// Agora, in Pendentes, in Para depois, on a task's own page.
///
/// A task with tasks of its own (what used to be a delivery) and a task
/// without them are the same card. On the left, the play button, which
/// is the same as letting the task go on Agora; the running task draws
/// pause there instead. The title is always the task's: when the work
/// going on is one of its tasks, that one is the [subtitle].
///
/// Agora's card ([now]) glows as the running card always has. A card with
/// [controls] says where it stands ([status]) and has −10, +10 and ✓ to
/// its side, with its [bar] below, as thin as Agora's.
/// {@endtemplate}
class TaskCard extends StatelessWidget {
  /// {@macro task_card}
  const TaskCard({
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingInk,
    this.fill,
    this.step = TaskStep.minutes,
    this.now = false,
    this.playing = false,
    this.onPlay,
    this.status,
    this.statusInk,
    this.controls = false,
    this.onLess,
    this.onMore,
    this.onDone,
    this.bar,
    this.onTap,
    this.keepPlaySlot = false,
    super.key,
  });

  /// The task's name.
  final String title;

  /// The task of it at work, or what it is for (the product, the
  /// delivery it belongs to).
  final String? subtitle;

  /// On the right of the title: its hours, or its length.
  final String? trailing;

  /// The colour of [trailing] when it is a warning ("para ontem").
  final Color? trailingInk;

  /// The card's fill, when not the quiet one: [AppColors.urgentFill] for a
  /// task past its day.
  final Color? fill;

  /// What −/+ change ([controls]).
  final TaskStep step;

  /// Whether this is the card on Agora.
  final bool now;

  /// Whether it is running: the button pauses it.
  final bool playing;

  /// Plays it (or pauses it, [playing]). Without it there is no button,
  /// which is a fixed event's case.
  final VoidCallback? onPlay;

  /// Where it stands, over the bar.
  final String? status;

  /// The colour of [status] when it is a warning.
  final Color? statusInk;

  /// Whether −10, +10 and ✓ are drawn beside [status].
  final bool controls;

  /// Ten minutes less ([controls]); null draws it faded.
  final VoidCallback? onLess;

  /// Ten minutes more ([controls]).
  final VoidCallback? onMore;

  /// Done ([controls]).
  final VoidCallback? onDone;

  /// The bar under it.
  final TaskBar? bar;

  /// Opens the task.
  final VoidCallback? onTap;

  /// Without [onPlay], whether the button's room is kept, so a fixed block
  /// among tasks lines its title up with theirs.
  final bool keepPlaySlot;

  /// [subtitle], unless it only says the title again: a task whose one
  /// task is itself is drawn by its name alone.
  String? get _subtitle {
    final line = subtitle?.trim();
    if (line == null || line.isEmpty) return null;
    if (line.toLowerCase() == title.trim().toLowerCase()) return null;
    return line;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.chipRadius);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            // The play button and the hours sit on the title's line, not in
            // the middle of a two-line card.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onPlay != null) ...[
                TaskPlayButton(playing: playing, onPressed: onPlay),
                const SizedBox(width: AppSpacing.s3),
              ] else if (keepPlaySlot)
                const SizedBox(width: TaskPlayButton.size + AppSpacing.s3)
              else
                const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: AppSpacing.s3),
                          Text(
                            trailing!,
                            style: AppTypography.label.copyWith(
                              color: AppColors.ink3,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (status != null || controls) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                const SizedBox(width: AppSpacing.s1),
                Expanded(
                  child: Text(
                    status ?? '',
                    style: AppTypography.label.copyWith(
                      color: statusInk ?? AppColors.ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controls)
                  _Steps(
                    step: step,
                    onLess: onLess,
                    onMore: onMore,
                    onDone: onDone,
                  ),
              ],
            ),
          ],
          if (bar != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s1),
              child: TaskCardBar(bar: bar!),
            ),
          ],
        ],
      ),
    );

    return Material(
      type: now ? MaterialType.transparency : MaterialType.canvas,
      color: now ? null : fill ?? AppColors.fill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: now ? NowSurface(paused: !playing, child: body) : body,
      ),
    );
  }
}

/// {@template task_play_button}
/// The round button at the left of every task: play, or pause while it
/// runs. Playing a task is letting it go on Agora.
/// {@endtemplate}
class TaskPlayButton extends StatelessWidget {
  /// {@macro task_play_button}
  const TaskPlayButton({required this.playing, this.onPressed, super.key});

  /// Whether the task runs: the button pauses it.
  final bool playing;

  /// Plays or pauses it.
  final VoidCallback? onPressed;

  /// Its diameter. Small and quiet: the card is the task, the button only
  /// one way to begin it. A tap lands in [_target] around it.
  static const double size = AppSpacing.s6;

  static const double _target = AppSpacing.s8;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing
          ? context.l10n.controlPause
          : context.l10n.controlStartNow,
      child: InkResponse(
        onTap: onPressed,
        radius: _target / 2,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: playing ? AppColors.accentSoft : AppColors.fillStrong,
            ),
            child: Center(
              child: AppIcon(
                iconData: playing ? AppIcons.pause : AppIcons.play,
                size: AppSpacing.s3,
                color: playing ? AppColors.accent : AppColors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// −10, +10 and ✓, quiet, as Agora draws them.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.step,
    this.onLess,
    this.onMore,
    this.onDone,
  });

  final TaskStep step;
  final VoidCallback? onLess;
  final VoidCallback? onMore;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = step == TaskStep.days;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Step(
          tooltip: days ? l10n.controlDayEarlier : l10n.controlLess10,
          onTap: onLess,
          child: Text(
            days ? l10n.stepDayLess : '−$stepMinutes',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        _Step(
          tooltip: days ? l10n.controlDayLater : l10n.controlMore10,
          onTap: onMore,
          child: Text(
            days ? l10n.stepDayMore : '+$stepMinutes',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        _Step(
          tooltip: l10n.controlDone,
          onTap: onDone,
          child: const AppIcon(
            iconData: AppIcons.check,
            size: AppSpacing.s4,
            color: AppColors.ink2,
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.tooltip, required this.child, this.onTap});

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpacing.s5,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: SizedBox(
            width: AppSpacing.s8 + AppSpacing.s1,
            height: AppSpacing.s6,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Agora's bar, 3 px, under a [TaskCard]: the accent alone for the running
/// block; for a task owed by a day, its work in [AppColors.paceDone] over
/// its time in [AppColors.paceTime].
class TaskCardBar extends StatelessWidget {
  /// The bar for [bar].
  const TaskCardBar({required this.bar, super.key});

  /// What it measures.
  final TaskBar bar;

  @override
  Widget build(BuildContext context) {
    final time = bar.late ? 1.0 : bar.time;
    final pace = time != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.line),
            if (pace) _Fill(value: time, color: AppColors.paceTime),
            _Fill(
              value: bar.done,
              color: pace ? AppColors.paceDone : AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0, 1),
      child: ColoredBox(color: color),
    );
  }
}

/// {@template now_task_card}
/// Agora's card: the task being lived through as a [TaskCard], pause on
/// its left (play once paused), −10, +10 and ✓ beside where it stands,
/// and the running bar under it.
///
/// Titled by the task: a delivery's name, with its task at work under it
/// ([byParent]); on the delivery's own page, which already names it, by the
/// task at work. A fixed block, a task waiting to be begun and one in
/// overtime keep the tile the calendar draws ([EventTile]), whose buttons
/// answer those.
/// {@endtemplate}
class NowTaskCard extends StatelessWidget {
  /// {@macro now_task_card}
  const NowTaskCard({
    required this.card,
    required this.now,
    this.byParent = true,
    this.onTap,
    super.key,
  });

  /// The card on Agora.
  final TimelineEvent card;

  /// The moment it is drawn at.
  final DateTime now;

  /// Whether a delivery's task is titled by the delivery.
  final bool byParent;

  /// Opens it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final bloc = context.read<TimelineBloc>();

    if (!card.isTask || !card.started || card.isLate) {
      return EventTile(
        card: card,
        onPauseToggled: () => bloc.add(EventPauseToggled(card.id)),
        onAdjusted: (minutes) => unawaited(adjustTime(context, card, minutes)),
        onDone: () => bloc.add(EventFinished(card.id)),
        onStarted: () => bloc.add(EventStarted(card.id)),
        onSnoozed: () => bloc.add(EventSnoozed(card.id)),
      );
    }

    final parent = byParent ? card.artifactTitle : null;
    return TaskCard(
      title: parent ?? card.title,
      subtitle: parent == null ? null : card.title,
      trailing: '${hhmm(card.startTime)} – ${hhmm(card.endTime)}',
      now: true,
      playing: !card.isPaused,
      onPlay: () => bloc.add(EventPauseToggled(card.id)),
      controls: true,
      onLess: card.canShorten(stepMinutes, now)
          ? () => unawaited(adjustTime(context, card, -stepMinutes))
          : null,
      onMore: () => unawaited(adjustTime(context, card, stepMinutes)),
      onDone: () => bloc.add(EventFinished(card.id)),
      bar: TaskBar(done: card.progressAt(now)),
      onTap: onTap,
    );
  }
}
