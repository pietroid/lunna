import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/now_surface.dart';

/// The bar under a [TaskCard]: how much of its work is done and, when it
/// is owed by a day, how much of its time has gone.
class TaskBar {
  /// Work done, 0 to 1, over [time] gone, 0 to 1. Without [time] the bar is
  /// Agora's: one fill, the accent, the block's own minutes.
  const TaskBar({required this.done, this.time});

  /// The work done, 0 to 1.
  final double done;

  /// The time gone from its start to its day, 0 to 1; null when it is owed
  /// by no day, or for the running block.
  final double? time;
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
    this.now = false,
    this.playing = false,
    this.onPlay,
    this.status,
    this.statusInk,
    this.controls = false,
    this.bar,
    this.onTap,
    super.key,
  });

  /// The task's name.
  final String title;

  /// The task of it at work, or what it is for (the product, the
  /// delivery it belongs to).
  final String? subtitle;

  /// On the right of the title: its hours, or its length.
  final String? trailing;

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

  /// The bar under it.
  final TaskBar? bar;

  /// Opens the task.
  final VoidCallback? onTap;

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
            children: [
              if (onPlay != null) ...[
                TaskPlayButton(playing: playing, onPressed: onPlay),
                const SizedBox(width: AppSpacing.s3),
              ] else
                const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.s3),
                Text(
                  trailing!,
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ],
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
                if (controls) const _Steps(),
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
      color: now ? null : AppColors.fill,
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

  static const double _size = AppSpacing.s8;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing
          ? context.l10n.controlPause
          : context.l10n.controlStartNow,
      child: Material(
        color: playing ? AppColors.accent : AppColors.fillStrong,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _size,
            child: Center(
              child: AppIcon(
                iconData: playing ? AppIcons.pause : AppIcons.play,
                size: AppSpacing.s4,
                color: playing ? AppColors.onAccent : AppColors.ink,
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
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Step(
          tooltip: l10n.controlLess10,
          child: Text(
            '−$stepMinutes',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        _Step(
          tooltip: l10n.controlMore10,
          child: Text(
            '+$stepMinutes',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        _Step(
          tooltip: l10n.controlDone,
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
  const _Step({required this.tooltip, required this.child});

  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {},
      radius: AppSpacing.s5,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: AppSpacing.s8 + AppSpacing.s1,
          height: AppSpacing.s6,
          child: Center(child: child),
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
    final time = bar.time;
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
