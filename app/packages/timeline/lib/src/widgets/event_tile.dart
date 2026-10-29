import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/checklist.dart';
import 'package:timeline/src/widgets/format.dart';
import 'package:timeline/src/widgets/now_surface.dart';

/// {@template event_tile}
/// One card on the timeline: a block of time.
///
/// The title, and the hours it starts and ends on the right. Later in the day
/// the card is as tall as its time, near enough, and the hours are what say
/// exactly how much of the day it takes. A fixed card says so with a pin: it
/// is the one card on the screen that will not move when the day is
/// rearranged, and that is worth knowing before rearranging it. A routine's
/// day carries a repeat mark and its own navy fill, so lunch reads as lunch
/// before its title does.
///
/// A flexible block whose hour has come waits for the user. It is drawn as
/// the running card exactly, paused at its first minute: the play button
/// begins it, and +15 gives it fifteen minutes more, which takes it out of
/// Agora until then.
///
/// A meeting Lunna did not book looks the same and behaves differently: it
/// carries a small mark saying where it came from, and the list above ignores
/// every gesture on it.
///
/// On the calendar ([preview]) a card also says what its notes start with
/// and which artifact it is of, in the room its time already gives it and
/// never more: a card with room for a second line draws them under the
/// title, as many lines as fit up to three; a shorter one shows no notes at
/// all, and marks an artifact's task with the folders.
///
/// A routine's day with a list of its own (breakfast: the coffee, the
/// dishes) draws the list in place of the notes: the next item to do, with
/// how many are done, and on the calendar, when the card is tall enough for
/// a line per item, every item one under another. Agora draws the next one
/// alone. Items are ticked off on the block's own page.
///
/// It carries no gestures of its own. Tapping and dragging on the timeline
/// are read by one listener over the whole list, which tells each card how it
/// is being touched through [pressed], [hidden], and [lifted].
/// {@endtemplate}
class EventTile extends StatelessWidget {
  /// {@macro event_tile}
  const EventTile({
    required this.card,
    this.pressed = false,
    this.hidden = false,
    this.lifted = false,
    this.landing,
    this.preview = false,
    this.actionsKey,
    this.onPauseToggled,
    this.onAdjusted,
    this.onDone,
    this.onStarted,
    this.onSnoozed,
    super.key,
  });

  /// The card to draw.
  final TimelineEvent card;

  /// Whether a finger is resting on it.
  final bool pressed;

  /// Whether this is the place a card in the air left open behind it.
  ///
  /// It is still laid out, and still the full size it was, so the list it
  /// left keeps the shape it had while it is gone.
  final bool hidden;

  /// Whether this is the copy that follows the finger.
  final bool lifted;

  /// The hours it would have if it were let go now, which the copy under the
  /// finger reads in place of its own.
  final ({DateTime start, DateTime end})? landing;

  /// Whether the card says what its notes start with and its artifact's
  /// name, within the height it is given (the calendar's).
  final bool preview;

  /// How tall a card on the calendar must be for a second line.
  static const _twoLines = 72.0;

  /// How far down a card its list starts: the padding and the title.
  static const _listTop = 50.0;

  /// Put on the row of buttons, so the list's own gesture can leave a tap on
  /// one of them alone.
  final Key? actionsKey;

  /// Pauses or resumes. The buttons are only drawn when this is given.
  final VoidCallback? onPauseToggled;

  /// Asks for fifteen minutes more, or fewer when negative.
  final ValueChanged<int>? onAdjusted;

  /// Marks it done.
  final VoidCallback? onDone;

  /// Begins a block that is waiting to be begun.
  final VoidCallback? onStarted;

  /// Gives a waiting block fifteen minutes more.
  final VoidCallback? onSnoozed;

  /// Whether this is the block being lived through.
  bool get _isNow => card.section == TimelineSection.agora;

  @override
  Widget build(BuildContext context) {
    final body = preview
        ? LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              // Agora is drawn as it needs, so it gets no second line.
              final lines = height.isFinite && height >= _twoLines
                  ? ((height - 64) / 18).floor().clamp(1, 3)
                  : 0;
              final items = height.isFinite && !_isNow
                  ? ((height - _listTop) / ChecklistLine.height).floor()
                  : 1;
              return _body(context, lines: lines, items: items);
            },
          )
        : _body(context, lines: 0);

    return Opacity(
      opacity: hidden ? 0 : 1,
      child: Material(
        type: _isNow ? MaterialType.transparency : MaterialType.canvas,
        color: _isNow
            ? null
            : pressed || lifted
            ? AppColors.fillStrong
            : _isFixed
            ? AppColors.fixedFill
            : card.isRoutine
            ? AppColors.routineFill
            : AppColors.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        elevation: lifted ? 8 : 0,
        shadowColor: AppColors.bg,
        child: _isNow
            ? NowSurface(
                // Waiting is quiet, like a pause: nothing is running yet.
                paused: card.isPaused || card.awaitingStart,
                pressed: pressed || lifted,
                child: body,
              )
            : body,
      ),
    );
  }

  /// The card's words: the title and its hours, then, given [lines] of room
  /// under them, the artifact and the start of the notes, or, for a day
  /// with a list, as many of its [items] as there is room for.
  Widget _body(BuildContext context, {required int lines, int items = 1}) {
    final list = card.checklist;
    final notes = preview && list.isEmpty ? notesPreview(card.notes) : '';
    final artifact = preview ? card.artifactTitle : null;
    final under = lines > 0 && (notes.isNotEmpty || artifact != null);
    final mark =
        _mark ??
        (preview && !under && artifact != null ? AppIcons.artifacts : null);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // The mark comes before the title, where it reads as "this one
              // is a meeting" or "this one is pinned", rather than after it,
              // where it would read as a status the block had earned.
              if (mark != null) ...[
                AppIcon(
                  iconData: mark,
                  size: AppSpacing.s4,
                  color: _quiet,
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Expanded(
                child: Text(
                  card.title,
                  style: AppTypography.body.copyWith(
                    color: card.isPaused ? AppColors.ink2 : AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                // Nothing in the backlog has an hour, only a length, until
                // it is aimed at the queue.
                card.isBacklog && landing == null
                    ? durationLabel(context.l10n, card.workMinutes)
                    : '${hhmm(landing?.start ?? card.startTime)}–'
                          '${hhmm(landing?.end ?? card.endTime)}',
                style: AppTypography.label.copyWith(color: _quiet),
              ),
            ],
          ),
          // The notes go under the title or nowhere: with no room for that
          // line the card is its title alone.
          if (under) ...[
            const SizedBox(height: AppSpacing.s1),
            Text.rich(
              TextSpan(
                children: [
                  if (artifact != null)
                    TextSpan(
                      text: artifact,
                      style: AppTypography.labelStrong.copyWith(
                        color: _isFixed || card.isRoutine
                            ? _quiet
                            : AppColors.ink2,
                      ),
                    ),
                  if (artifact != null && notes.isNotEmpty)
                    const TextSpan(text: ' · '),
                  if (notes.isNotEmpty) TextSpan(text: notes),
                ],
              ),
              style: AppTypography.label.copyWith(color: _quiet),
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // The list goes where the notes would: every item when the
          // calendar has a line for each, else the next one alone.
          if (list.isNotEmpty && items > 0) ...[
            const SizedBox(height: AppSpacing.s1),
            if (preview && !_isNow && list.length > 1 && items >= list.length)
              for (final item in list) ChecklistLine(item: item, quiet: _quiet)
            else
              ChecklistLine.next(context, card, quiet: _quiet),
          ],
          // Late, the bar has nothing left to measure: what is left is
          // how late it is, and the answer to it.
          if (_isNow && card.isLate) ...[
            const SizedBox(height: AppSpacing.s2),
            NowLate(
              key: actionsKey,
              card: card,
              onDone: card.isInteractive ? onDone : null,
              onAdjusted: card.isInteractive ? onAdjusted : null,
            ),
          ] else if (_isNow) ...[
            const SizedBox(height: AppSpacing.s2),
            NowProgress(card: card, trailing: _actions()),
          ],
        ],
      ),
    );
  }

  /// Pause, ten minutes either way, and done, when there is anyone to
  /// tell.
  Widget? _actions() {
    if (!card.isInteractive || onPauseToggled == null) return null;

    return EventControls(
      key: actionsKey,
      card: card,
      onPauseToggled: onPauseToggled,
      onStarted: onStarted,
      onSnoozed: onSnoozed,
      onAdjusted: onAdjusted!,
      onDone: onDone,
    );
  }

  /// Whether the card is drawn as a fixed block, which wins over a
  /// routine's colour: a fixed routine's day is a wall of the day first.
  bool get _isFixed => !card.isTask && card.fixed;

  /// The colour of the mark and the hours: lifted off the fill on a fixed
  /// block or a routine's day, where grey would sink into it.
  Color get _quiet {
    if (_isNow || lifted || pressed) return AppColors.ink3;
    if (_isFixed) return AppColors.fixedInk;
    if (card.isRoutine) return AppColors.routineInk;
    return AppColors.ink3;
  }

  /// The small icon in front of the title, when the card has earned one.
  AppIconData? get _mark {
    if (!card.managed) return AppIcons.calendar;
    if (card.isRoutine) return AppIcons.repeat;
    return card.fixed ? AppIcons.pin : null;
  }
}

/// {@template event_controls}
/// The quiet row of buttons a block is worked with.
///
/// Pause or resume while it runs, start it now when it has not started,
/// fifteen minutes either way, and done. The running card on the timeline and
/// the block's own screen draw the same row, so a button means the same thing
/// in both places.
///
/// A block waiting to be begun draws the same row as a paused one. Play
/// begins it, and +15 is fifteen minutes before it asks again rather than
/// fifteen minutes more of work, because none of its work has started.
/// {@endtemplate}
class EventControls extends StatelessWidget {
  /// {@macro event_controls}
  const EventControls({
    required this.card,
    required this.onAdjusted,
    this.onDone,
    this.onPauseToggled,
    this.onStarted,
    this.onSnoozed,
    super.key,
  });

  /// The block.
  final TimelineEvent card;

  /// Pauses or resumes. Only drawn while it runs.
  final VoidCallback? onPauseToggled;

  /// Starts it now. Only drawn before it has started.
  final VoidCallback? onStarted;

  /// Gives a waiting block fifteen minutes before it asks again.
  final VoidCallback? onSnoozed;

  /// Asks for fifteen minutes more, or fewer when negative.
  final ValueChanged<int> onAdjusted;

  /// Marks it done. Null leaves the check out, for a page that ticks the
  /// block off by the circle before its name.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final running = card.isRunningAt(now);
    final shortens = card.canShorten(stepMinutes, now);
    final waiting = card.awaitingStart && onSnoozed != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A block waiting to be begun is running on the clock and not in
        // fact, so its button begins it rather than pausing it.
        if (card.awaitingStart && onStarted != null)
          _Action(
            tooltip: context.l10n.controlStart,
            onTap: onStarted,
            child: const AppIcon(
              iconData: AppIcons.play,
              size: AppSpacing.s4,
              color: AppColors.ink,
            ),
          )
        else if (running && onPauseToggled != null)
          _Action(
            tooltip: card.isPaused
                ? context.l10n.controlResume
                : context.l10n.controlPause,
            onTap: onPauseToggled,
            child: AppIcon(
              iconData: card.isPaused ? AppIcons.play : AppIcons.pause,
              size: AppSpacing.s4,
              color: card.isPaused ? AppColors.ink : AppColors.ink2,
            ),
          )
        else if (!running && onStarted != null)
          _Action(
            tooltip: context.l10n.controlStartNow,
            onTap: onStarted,
            child: const AppIcon(
              iconData: AppIcons.play,
              size: AppSpacing.s4,
              color: AppColors.ink2,
            ),
          ),
        _Action(
          tooltip: context.l10n.controlLess10,
          onTap: shortens ? () => onAdjusted(-stepMinutes) : null,
          child: Text(
            '−$stepMinutes',
            style: AppTypography.labelStrong.copyWith(
              color: shortens ? AppColors.ink2 : AppColors.ink3,
            ),
          ),
        ),
        _Action(
          tooltip: waiting
              ? context.l10n.controlWait10
              : context.l10n.controlMore10,
          onTap: waiting ? onSnoozed : () => onAdjusted(stepMinutes),
          child: Text(
            '+$stepMinutes',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        if (onDone != null)
          _Action(
            tooltip: context.l10n.controlDone,
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

/// One quiet button in [EventControls].
class _Action extends StatelessWidget {
  const _Action({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;

  /// Null when the button cannot do anything right now.
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpacing.s5,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: AppSpacing.s8 + AppSpacing.s1,
          height: AppSpacing.s8,
          child: Center(child: child),
        ),
      ),
    );
  }
}
