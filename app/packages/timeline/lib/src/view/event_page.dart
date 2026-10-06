import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/format.dart';
import 'package:timeline/src/widgets/widgets.dart';

/// {@template event_page}
/// One task or one block of time, opened.
///
/// The top of the screen is the block: its name beside the back button,
/// edited where it is written, then its hour and length, each a tap away from
/// a picker, and the same row of buttons the running card has on the
/// timeline. A block that is running adds its progress bar and nothing else,
/// so the screen reads the same before, during and after.
///
/// Everything under that is the block's notes: free text, saved as it is
/// written.
///
/// A task's hour is the queue's to give, so only an event's hour opens a
/// picker here; a task's length does, and its place is changed by dragging
/// it in the list.
///
/// The card is read from the timeline rather than fetched. It is the card
/// the user just tapped, and every change made here lands on the timeline
/// first, so the two can never disagree.
/// {@endtemplate}
class EventPage extends StatelessWidget {
  /// {@macro event_page}
  const EventPage({required this.id, super.key});

  /// The card's id: the task's for a task, the event's for an event.
  final String id;

  @override
  Widget build(BuildContext context) {
    final card = context.select<TimelineBloc, TimelineEvent?>(
      (bloc) => bloc.state.byId(id),
    );
    final guard = context.select<TimelineBloc, StartNowGuard?>(
      (bloc) => bloc.state.guard,
    );
    final busy = context.select<TimelineBloc, bool>(
      (bloc) => bloc.state.guardBusy,
    );

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: card == null ? null : _Title(card: card),
        actions: [
          if (card != null && card.isInteractive)
            AppIconButton(
              iconData: AppIcons.trash,
              color: AppColors.ink2,
              onPressed: () => unawaited(_delete(context, card)),
            ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: card == null
                    ? const _Gone()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Summary(card: card),
                          const Divider(height: 1, color: AppColors.line),
                          Expanded(
                            // Keyed by the block, so the field never carries
                            // one block's text over to another.
                            child: _Notes(key: ValueKey(card.id), card: card),
                          ),
                        ],
                      ),
              ),
            ),
            // "Começar agora" can ask what happens to what is running, and
            // the question belongs on the screen the button was on.
            if (guard != null) GuardSheet(guard: guard, busy: busy),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, TimelineEvent card) async {
    final bloc = context.read<TimelineBloc>();
    final navigator = Navigator.of(context);

    if (await confirmDelete(context, card.title)) {
      bloc.add(EventDeleted(card.id));
      navigator.pop();
    }
  }
}

/// The name, edited where it is written, in the bar beside the back button.
class _Title extends StatefulWidget {
  const _Title({required this.card});

  final TimelineEvent card;

  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> {
  late final _controller = TextEditingController(text: widget.card.title);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_Title oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The server's name wins whenever the user is not in the middle of
    // typing a new one.
    if (!_focus.hasFocus && widget.card.title != _controller.text) {
      _controller.text = widget.card.title;
    }
  }

  void _commit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      _controller.text = widget.card.title;
      return;
    }
    if (title == widget.card.title) return;

    context.read<TimelineBloc>().add(EventEdited(widget.card.id, title: title));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.card.isInteractive,
      style: AppTypography.title,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration.collapsed(
        hintText: context.l10n.eventUntitled,
      ),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}

/// When the block is, how long it takes, and the buttons.
///
/// The same lines whether or not it is running. Running only adds the
/// progress bar, which is the one thing that is true of a running block and
/// of nothing else.
class _Summary extends StatelessWidget {
  const _Summary({required this.card});

  final TimelineEvent card;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final running = card.isRunningAt(now);
    final controls = card.isInteractive ? _controls(context) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _When(card: card),
          const SizedBox(height: AppSpacing.s2),
          if (running)
            NowProgress(card: card, trailing: controls)
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    _startsIn(context.l10n, card.startTime, now),
                    style: AppTypography.label.copyWith(color: AppColors.ink2),
                  ),
                ),
                ?controls,
              ],
            ),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final bloc = context.read<TimelineBloc>();

    return EventControls(
      card: card,
      onPauseToggled: () => bloc.add(EventPauseToggled(card.id)),
      // Begins a waiting task, or brings one that has not reached its hour
      // to the top of the day; the server tells the two apart. An event
      // begins at its hour, and has nothing to ask.
      onStarted: card.isTask ? () => bloc.add(EventStarted(card.id)) : null,
      onAdjusted: (minutes) => unawaited(adjustTime(context, card, minutes)),
      onDone: () async {
        bloc.add(EventFinished(card.id));
        await Navigator.of(context).maybePop();
      },
    );
  }

  /// "Começa em 25 min", or the hour when it is further off than that.
  static String _startsIn(AppLocalizations l10n, DateTime start, DateTime now) {
    final minutes = start.difference(now).inMinutes;
    if (minutes < 1) return l10n.eventStartsNow;
    if (minutes < 60) return l10n.eventStartsIn(minutes);

    final days = DateTime(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return switch (days) {
      <= 0 => l10n.eventStartsAt(hhmm(start)),
      1 => l10n.eventStartsTomorrowAt(hhmm(start)),
      _ => l10n.eventDayAt(start.day, start.month, hhmm(start)),
    };
  }
}

/// The hour and the length, each opening its picker.
class _When extends StatelessWidget {
  const _When({required this.card});

  final TimelineEvent card;

  @override
  Widget build(BuildContext context) {
    final started = !card.startTime.isAfter(DateTime.now());
    final editable = card.isInteractive;

    return Row(
      children: [
        if (card.fixed) ...[
          const AppIcon(
            iconData: AppIcons.pin,
            size: AppSpacing.s4,
            color: AppColors.ink3,
          ),
          const SizedBox(width: AppSpacing.s1),
        ],
        _Tappable(
          text: _startLabel(context.l10n, card.startTime),
          // A task's hour is wherever the queue puts it.
          onTap: editable && !started && !card.isTask
              ? () => _pickStart(context)
              : null,
        ),
        Text(
          ' · ',
          style: AppTypography.label.copyWith(color: AppColors.ink3),
        ),
        _Tappable(
          text: durationLabel(context.l10n, card.workMinutes),
          onTap: editable ? () => _pickDuration(context) : null,
        ),
      ],
    );
  }

  /// "14:30", or "amanhã 09:00" when it is not today.
  static String _startLabel(AppLocalizations l10n, DateTime start) {
    final now = DateTime.now();
    final days = DateTime(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return switch (days) {
      <= 0 => hhmm(start),
      1 => l10n.eventTomorrowAt(hhmm(start)),
      _ => l10n.eventDayAt(start.day, start.month, hhmm(start)),
    };
  }

  /// A new hour for an event, the day part of naming it, as the creation
  /// sheet does.
  Future<void> _pickStart(BuildContext context) async {
    final bloc = context.read<TimelineBloc>();
    final now = DateTime.now();
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: card.startTime.isBefore(now) ? now : card.startTime,
      earliest: now.subtract(const Duration(minutes: 5)),
    );
    if (picked == null) return;

    bloc.add(EventEdited(card.id, startTime: picked));
  }

  Future<void> _pickDuration(BuildContext context) async {
    final bloc = context.read<TimelineBloc>();
    final picked = await AppWheelPicker.duration(
      context,
      initial: Duration(minutes: _roundedToFive(card.workMinutes)),
    );
    if (picked == null || picked.inMinutes <= 0) return;
    if (picked.inMinutes == card.workMinutes) return;

    bloc.add(EventEdited(card.id, workMinutes: picked.inMinutes));
  }

  static int _roundedToFive(int minutes) =>
      ((minutes / 5).round() * 5).clamp(5, 24 * 60);
}

/// A piece of the time line that opens a picker, when it can.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: AppTypography.labelStrong.copyWith(
        color: onTap == null ? AppColors.ink2 : AppColors.ink,
      ),
    );
    if (onTap == null) return label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
        child: label,
      ),
    );
  }
}

/// The block's notes: free text, saved as it is written.
///
/// Saved a moment after the typing stops, and again when the field loses
/// focus or the page closes, so nothing written is ever lost to a back
/// gesture. The server's copy only replaces the field's while the user is not
/// in it, so a save landing mid-sentence never moves the cursor.
class _Notes extends StatefulWidget {
  const _Notes({required this.card, super.key});

  final TimelineEvent card;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  static const _debounce = Duration(milliseconds: 800);

  late final _controller = TextEditingController(text: widget.card.notes);
  final _focus = FocusNode();
  late final TimelineBloc _bloc = context.read<TimelineBloc>();
  Timer? _timer;

  /// What was last sent, so the same text is never saved twice.
  late String _saved = widget.card.notes;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(_Notes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.card.notes != _controller.text) {
      _controller.text = widget.card.notes;
      _saved = widget.card.notes;
    }
  }

  void _onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_debounce, _save);
  }

  void _save() {
    _timer?.cancel();
    final notes = _controller.text;
    if (notes == _saved) return;

    _saved = notes;
    _bloc.add(EventEdited(widget.card.id, notes: notes));
  }

  @override
  void dispose() {
    _save();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s4,
        AppSpacing.s6,
        AppSpacing.s8,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: widget.card.isInteractive,
        onChanged: _onChanged,
        maxLines: null,
        minLines: 6,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: AppTypography.body,
        decoration: InputDecoration.collapsed(
          hintText: context.l10n.eventNotesHint,
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        ),
      ),
    );
  }
}

/// What the page says when the block is no longer on the day.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Text(
        context.l10n.eventGone,
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
    );
  }
}
