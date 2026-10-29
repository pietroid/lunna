import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template reminders_listener}
/// Keeps the reminder queue in step with the day, and opens what a reminder
/// was about when it is tapped.
///
/// A tap on the reminder itself always opens the app on its card, whatever
/// it asked. On iOS its buttons answer it without the app: Confirmar and
/// +10 min are posted from the background (`answerReminderInBackground`),
/// and Falar com a Lunna opens the app here, with the agent's sheet about
/// the card.
///
/// Android draws no buttons yet (#56), so there a task's start reminder
/// still opens the question, begin it now or in ten minutes, and until one
/// is answered the task keeps sliding down the day with the clock. The
/// notification is not the only way back into the app, so the question
/// does not depend on it: opening the app, or bringing it back, while a
/// task is still waiting asks the same question. Once per opening: a
/// dismissed question is left to the card, which goes on saying it is
/// waiting.
///
/// The queue is re-synced when the app comes back to the foreground and
/// whenever a block on the timeline is added, moved, renamed, paused or taken
/// off, whoever did it: the sheet, a drag, or a conversation that booked
/// something.
///
/// It keeps the Lock Screen's activity on the block that runs too
/// ([LiveActivity]), opens the card it is tapped on, and reads the day
/// again when one of its buttons changed it.
///
/// It is also where permission is asked, and only once: the first time a
/// block appears on a day the app had already loaded, which is the first
/// moment a reminder would be for something.
/// {@endtemplate}
class RemindersListener extends StatefulWidget {
  /// {@macro reminders_listener}
  const RemindersListener({required this.child, super.key});

  /// The screen underneath.
  final Widget child;

  @override
  State<RemindersListener> createState() => _RemindersListenerState();
}

class _RemindersListenerState extends State<RemindersListener>
    with WidgetsBindingObserver {
  late final NotificationScheduler _scheduler;
  late final StreamSubscription<NotificationTap> _taps;
  late final LiveActivity _live;
  late final StreamSubscription<String> _activityTaps;
  late final StreamSubscription<void> _activityChanges;

  /// The day as it was last loaded, so a change can be told from a reload.
  late TimelineState _last;
  bool _asking = false;

  /// Whether the next day loaded should be looked at for a block still
  /// waiting to be begun, which is true just after the app is opened.
  bool _lookForWaiting = false;

  /// The block the start question is open for, so it is never open twice.
  String? _askingStart;

  /// Whether the reminders' own buttons answer them, which makes the start
  /// question redundant: on iOS, and on Android once #56 lands.
  bool get _buttonsAnswer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _scheduler = context.read<NotificationScheduler>();
    _last = context.read<TimelineBloc>().state;
    WidgetsBinding.instance.addObserver(this);
    _taps = _scheduler.taps.listen(_open);
    _live = context.read<LiveActivity>();
    _activityTaps = _live.opened.listen(_openCard);
    final timeline = context.read<TimelineBloc>();
    _activityChanges = _live.changes.listen(
      (_) => timeline.add(const TimelineRequested()),
    );
    unawaited(_openLaunchTap());
    if (_last.status == TimelineStatus.success) {
      unawaited(_live.sync(_last.cards));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_taps.cancel());
    unawaited(_activityTaps.cancel());
    unawaited(_activityChanges.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(_scheduler.sync());
    // The day moved on while the app was away, so it is read again, and the
    // fresh one is the one asked about.
    _lookForWaiting = true;
    context.read<TimelineBloc>().add(const TimelineRequested());
  }

  /// Opens what the notification that launched the app was about, or looks
  /// for a waiting block when it was not launched from one.
  Future<void> _openLaunchTap() async {
    final card = await _live.launchCard();
    if (!mounted) return;
    if (card != null) {
      _openCard(card);
      return;
    }

    final tap = await _scheduler.launchTap();
    if (!mounted) return;

    if (tap != null) {
      _open(tap);
      return;
    }

    final day = context.read<TimelineBloc>().state;
    if (day.status == TimelineStatus.success) {
      _askIfWaiting(day);
    } else {
      _lookForWaiting = true;
    }
  }

  /// Asks about the block in Agora still waiting to be begun, if there is
  /// one.
  void _askIfWaiting(TimelineState day) {
    if (_buttonsAnswer) return;

    final waiting = day.tasks
        .where(
          (card) => card.section == TimelineSection.agora && card.awaitingStart,
        )
        .firstOrNull;
    if (waiting != null) unawaited(_askToStart(waiting.id, waiting.title));
  }

  void _open(NotificationTap tap) {
    if (!mounted) return;

    final eventId = tap.eventId;
    if (eventId == null) return;

    if (tap.action == NotificationAction.talk) {
      unawaited(
        showAgentSheet(
          context,
          about: tap.card == NotificationCard.task
              ? AgentSubject.task(eventId)
              : null,
        ),
      );
      return;
    }

    // Confirmar and +10 min are answered in the background; one that still
    // reaches the app is answered here, the same way.
    if (tap.answer != null) {
      unawaited(_answer(tap));
      return;
    }

    if (tap.asksToStartTask && !_buttonsAnswer) {
      unawaited(
        _askToStart(eventId, tap.title ?? context.l10n.remindersNextBlock),
      );
      return;
    }

    _openCard(eventId);
  }

  void _openCard(String id) {
    if (!mounted) return;
    unawaited(context.push<void>('/evento/${Uri.encodeComponent(id)}'));
  }

  Future<void> _answer(NotificationTap tap) async {
    final timeline = context.read<TimelineBloc>();
    await _scheduler.answer(tap);
    timeline.add(const TimelineRequested());
  }

  /// Asks whether the waiting task starts now or in ten minutes.
  Future<void> _askToStart(String eventId, String title) async {
    // A notification tapped while the app was opening, and the opening
    // itself, both ask. One sheet is enough.
    if (_askingStart != null) return;
    _askingStart = eventId;

    final timeline = context.read<TimelineBloc>()
      // The block has been sliding while the app was closed, so the day is
      // read again under the question.
      ..add(const TimelineRequested());

    final _StartAnswer? answer;
    try {
      answer = await _startSheet(context, title);
    } finally {
      _askingStart = null;
    }
    switch (answer) {
      case _StartAnswer.now:
        timeline.add(EventStarted(eventId));
      case _StartAnswer.later:
        timeline.add(EventSnoozed(eventId));
      case null:
        // Dismissed: nothing is decided, and the card on the timeline goes
        // on asking.
        break;
    }
  }

  void _onDay(TimelineState current) {
    // A reload passes through loading on its way back. Comparing against
    // that would make every block look new, so only a loaded day counts.
    if (current.status != TimelineStatus.success) return;

    if (_lookForWaiting) {
      _lookForWaiting = false;
      _askIfWaiting(current);
    }

    // Sent only when the block it shows changed; the timers count alone.
    unawaited(_live.sync(current.cards));

    final previous = _last;
    _last = current;
    if (_fingerprint(previous) == _fingerprint(current)) return;

    unawaited(_scheduler.sync());
    if (_gainedBlock(previous, current)) unawaited(_maybeAsk());
  }

  Future<void> _maybeAsk() async {
    if (_asking) return;
    _asking = true;

    try {
      if (!await _scheduler.shouldAskPermission() || !mounted) return;

      if (await _explain(context)) {
        await _scheduler.requestPermission();
      } else {
        await _scheduler.declinePermission();
      }
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimelineBloc, TimelineState>(
      listener: (context, state) => _onDay(state),
      child: widget.child,
    );
  }
}

/// Everything about the day a reminder depends on, as one string.
///
/// The timeline is fetched again on every minute boundary, and a sync per
/// minute would be a request per minute for nothing. This only changes when
/// a block Lunna booked does.
String _fingerprint(TimelineState state) {
  return [
    for (final card in state.cards)
      if (card.managed)
        [
          card.id,
          card.title,
          card.startTime.toIso8601String(),
          card.endTime.toIso8601String(),
          card.pausedAt != null,
        ].join('|'),
  ].join('\n');
}

/// Whether [current] has a block Lunna booked that a loaded [previous] did
/// not, which is someone having just put something on the day.
bool _gainedBlock(TimelineState previous, TimelineState current) {
  if (previous.status != TimelineStatus.success) return false;

  final before = {
    for (final card in previous.cards)
      if (card.managed) card.id,
  };

  return current.cards.any((card) => card.managed && !before.contains(card.id));
}

/// One line saying what reminders are for, before the system asks.
///
/// Resolves to true only on the button that turns them on.
Future<bool> _explain(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (sheetContext) => Material(
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
              Text(context.l10n.remindersAskTitle, style: AppTypography.title),
              const SizedBox(height: AppSpacing.s1),
              Text(
                context.l10n.remindersAskBody,
                style: AppTypography.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                text: context.l10n.remindersEnable,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: context.l10n.commonNotNow,
                color: AppColors.ink2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return accepted ?? false;
}

/// What the start question was answered with.
enum _StartAnswer { now, later }

/// The question a task's start reminder opens, on Android (#56).
///
/// One primary answer and one quiet one. Dismissing it answers nothing, and
/// the block keeps waiting.
Future<_StartAnswer?> _startSheet(BuildContext context, String title) {
  return showModalBottomSheet<_StartAnswer>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (sheetContext) => Material(
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
              Text(
                context.l10n.remindersStartTitle(title),
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                context.l10n.remindersStartBody,
                style: AppTypography.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                text: context.l10n.controlStartNow,
                expand: true,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_StartAnswer.now),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: context.l10n.controlWait10,
                color: AppColors.ink2,
                expand: true,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_StartAnswer.later),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
