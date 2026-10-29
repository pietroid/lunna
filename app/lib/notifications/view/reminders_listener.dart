import 'dart:async';
import 'dart:developer';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:lunna/notifications/view/reminder_sheet.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template reminders_listener}
/// Keeps the reminder queue in step with the day, and asks again in the app
/// what a tapped reminder asked.
///
/// A reminder carries no buttons (iOS draws them only when it is held
/// down). A tap opens the app on [ReminderSheet], over Tempo, with the
/// same question read again from the day (how late it is now, not when it
/// fired) and the answers the card's own buttons give: the ten minutes, the
/// answer, and Falar com a Lunna. Its answers post the card's routes saying
/// they came from a reminder. A reminder whose edge was already answered,
/// or one that asked nothing (a heads-up, the day's greetings), just opens
/// Tempo.
///
/// The queue is re-synced when the app comes back to the foreground and
/// whenever a block on the timeline is added, moved, renamed, paused or taken
/// off, whoever did it: the sheet, a drag, or a conversation that booked
/// something. Each sync also clears the reminders already shown but the
/// last, and an answer clears them all.
///
/// It hands the day to the Lock Screen's activity too ([LiveActivity]),
/// which is switched off ([kLiveActivity]) and so only ends one left
/// running.
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

  /// Whether a reminder's sheet is open, so a second tap does not stack
  /// another on it.
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _scheduler = context.read<NotificationScheduler>();
    _last = context.read<TimelineBloc>().state;
    WidgetsBinding.instance.addObserver(this);
    _taps = _scheduler.taps.listen((tap) => unawaited(_open(tap)));
    _live = context.read<LiveActivity>();
    _activityTaps = _live.opened.listen(_openCard);
    final timeline = context.read<TimelineBloc>();
    _activityChanges = _live.changes.listen(
      (_) => timeline.add(const TimelineRequested()),
    );
    unawaited(_openLaunchTap());
    // Ends an activity left running from before, the first thing it does.
    unawaited(
      _live.sync(
        _last.status == TimelineStatus.success ? _last.cards : const [],
      ),
    );
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
    context.read<TimelineBloc>().add(const TimelineRequested());
  }

  /// Asks what the reminder that launched the app asked, if one did.
  Future<void> _openLaunchTap() async {
    final card = await _live.launchCard();
    if (!mounted) return;
    if (card != null) {
      _openCard(card);
      return;
    }

    final tap = await _scheduler.launchTap();
    if (tap != null) await _open(tap);
  }

  /// Opens the sheet for [tap], on the day read again.
  Future<void> _open(NotificationTap tap) async {
    if (!mounted || !tap.asks || _answering) return;
    _answering = true;

    try {
      final day = await _freshDay();
      if (!mounted || day == null) return;

      final ask = ReminderAsk.of(tap, day, clock.now(), context.l10n);
      if (ask == null) return;

      final action = await ReminderSheet.show(context, ask);
      if (!mounted || action == null) return;

      await _answer(tap, action);
    } finally {
      _answering = false;
    }
  }

  /// The day as the server has it now, or null when it could not be read.
  ///
  /// The block went on while the app was away (it may be late by more now,
  /// or closed), so the question is never asked from the day in memory.
  Future<TimelineState?> _freshDay() async {
    final timeline = context.read<TimelineBloc>();
    final loaded = timeline.stream.firstWhere(
      (state) =>
          state.status == TimelineStatus.success ||
          state.status == TimelineStatus.failure,
    );
    timeline.add(const TimelineRequested());

    try {
      final day = await loaded.timeout(const Duration(seconds: 15));
      return day.status == TimelineStatus.success ? day : null;
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _answer(NotificationTap tap, NotificationAction action) async {
    final id = tap.eventId!;
    final card = tap.card!;

    if (action == NotificationAction.talk) {
      await showAgentSheet(
        context,
        about: card == NotificationCard.task ? AgentSubject.task(id) : null,
      );
      return;
    }

    final answer = NotificationAnswer.of(
      card: card,
      edge: tap.edge!,
      id: id,
      action: action,
    );
    if (answer == null) return;

    final timeline = context.read<TimelineBloc>();
    try {
      await _scheduler.answer(answer);
    } on Object catch (error, stackTrace) {
      // The card on Tempo says where the block stands, and asks the same.
      log(
        'reminder answer failed',
        name: 'notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
    timeline.add(const TimelineRequested());
  }

  void _openCard(String id) {
    if (!mounted) return;
    unawaited(context.push<void>('/evento/${Uri.encodeComponent(id)}'));
  }

  void _onDay(TimelineState current) {
    // A reload passes through loading on its way back. Comparing against
    // that would make every block look new, so only a loaded day counts.
    if (current.status != TimelineStatus.success) return;

    // Sent only when the block it shows changed; switched off, only once.
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
