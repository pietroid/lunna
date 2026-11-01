import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:lunna/tempo/view/minute_refresh.dart';
import 'package:timeline/timeline.dart';

/// How many tasks of Para depois Plano draws before the row that opens
/// them all.
const kLaterOnHome = 4;

/// {@template home_page}
/// Plano: what to do now, what is under way, and what comes later.
///
/// No greeting and no clock. From the top: the agent's one offer, as it
/// was; **Agora**, with the day's mark beside its heading (the cycle, a
/// light day, a day off) and *Ver o dia*, which opens the calendar on a
/// page of its own ([onSeeDay]), the running task and the one after it;
/// **Pendentes**, every task begun and not finished, drawn as Agora is,
/// with −10, +10 and ✓ and its bar under it; **Para depois**, the first
/// four of the queue ([kLaterOnHome]), and a row that opens the whole of
/// it ([onOpenLater]).
///
/// Every task has its play button on the left, which is letting it go on
/// Agora. The running one's is pause.
///
/// The offer is asked for again each time the tab comes to the front
/// ([shown]) and when a new day begins, since it is about the day. The day
/// is asked for again on every minute while the page is in sight, and the
/// deliveries whenever the day's tasks change, since their work is the
/// day's.
/// {@endtemplate}
class HomePage extends StatefulWidget {
  /// {@macro home_page}
  const HomePage({
    required this.onSeeDay,
    required this.onOpenLater,
    this.shown = true,
    this.controller,
    super.key,
  });

  /// Opens the calendar.
  final VoidCallback onSeeDay;

  /// Opens Para depois whole.
  final VoidCallback onOpenLater;

  /// Whether the tab is in front. Brought forward, it asks for the offer
  /// again; behind, it asks nothing.
  final bool shown;

  /// The scroll of the page.
  final ScrollController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SuggestionCubit _suggestion = SuggestionCubit(
    repository: context.read<AgentRepository>(),
  );

  /// The day the offer on screen was asked for.
  DateTime? _askedOn;

  /// Wakes at the next midnight.
  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the background on another day: the offer is yesterday's.
    _lifecycle = AppLifecycleListener(onShow: _askIfNewDay);
    if (widget.shown) _ask();
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown && !oldWidget.shown) _ask();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    unawaited(_suggestion.close());
    super.dispose();
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  void _ask() {
    _askedOn = _dayOf(clock.now());
    unawaited(_suggestion.load());
  }

  void _askIfNewDay() {
    if (!mounted || !widget.shown) return;
    if (_askedOn != _dayOf(clock.now())) _ask();
  }

  void _scheduleMidnight() {
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      _askIfNewDay();
      if (mounted) _scheduleMidnight();
    });
  }

  /// Asks for the day again on the minute, but not under an open guard:
  /// replacing the lists behind it would be the screen answering it.
  void _refresh() {
    final bloc = context.read<TimelineBloc>();
    if (bloc.state.guard != null) return;
    bloc.add(const TimelineRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = context.watch<TimelineBloc>().state;
    final deliveries = context.watch<ArtifactsCubit>().state.data;
    final now = clock.now();
    final items = PlanItems.of(day, deliveries, now);
    final guard = day.guard;
    final later = items.later.take(kLaterOnHome).toList();

    return BlocProvider<SuggestionCubit>.value(
      value: _suggestion,
      // A delivery's work is the day's tasks: when they change, so does it.
      child: BlocListener<TimelineBloc, TimelineState>(
        listenWhen: (before, after) =>
            before.tasks != after.tasks || before.backlog != after.backlog,
        listener: (context, _) =>
            unawaited(context.read<ArtifactsCubit>().load()),
        child: Stack(
          children: [
            if (widget.shown) MinuteRefresh(onRefresh: _refresh),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: ListView(
                    controller: widget.controller,
                    // The bottom bar, which the body runs under, comes in
                    // the padding; the dock floats over it.
                    padding: EdgeInsets.only(
                      top: AppSpacing.s3,
                      bottom:
                          MediaQuery.paddingOf(context).bottom +
                          kNotesDockClearance,
                    ),
                    children: [
                      // The agent's one unasked-for offer, first: it is
                      // about the day below it, and goes once taken or
                      // turned down.
                      const SuggestionCard(),
                      _Heading(
                        title: l10n.feedNow,
                        mark: day.marks.on(now),
                        action: AppPillButton(
                          label: l10n.feedSeeDay,
                          iconData: AppIcons.calendar,
                          onPressed: widget.onSeeDay,
                        ),
                      ),
                      _Pad(
                        child: _NowCard(card: items.now, now: now),
                      ),
                      if (items.next case final next?) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s6,
                            AppSpacing.s3,
                            AppSpacing.s6,
                            AppSpacing.s2,
                          ),
                          child: Text(
                            l10n.feedNext,
                            style: AppTypography.caption,
                          ),
                        ),
                        _Pad(child: _NextCard(card: next)),
                      ],
                      if (items.pending.isNotEmpty) ...[
                        _Heading(title: l10n.homePending),
                        for (final artifact in items.pending)
                          _Pad(
                            child: PendingCard(
                              key: ValueKey(artifact.id),
                              artifact: artifact,
                              now: now,
                            ),
                          ),
                      ],
                      _Heading(title: l10n.stageBacklog),
                      if (later.isEmpty)
                        _Pad(child: _Quiet(text: l10n.homeLaterEmpty)),
                      for (final item in later)
                        _Pad(
                          child: LaterCard(
                            key: ValueKey(item.id),
                            item: item,
                            now: now,
                          ),
                        ),
                      if (items.later.length > later.length)
                        _Pad(
                          child: _OpenRow(
                            text: l10n.homeLaterOpen(
                              items.later.length - later.length,
                            ),
                            onTap: widget.onOpenLater,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Play while something runs asks first, over the page, as a
            // drop on Agora does on the calendar.
            if (guard != null) GuardSheet(guard: guard, busy: day.guardBusy),
          ],
        ),
      ),
    );
  }
}

/// Agora: [NowTaskCard], or the break when nothing runs.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.card, required this.now});

  final TimelineEvent? card;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    if (card == null) return _Quiet(text: context.l10n.feedBreak);
    return NowTaskCard(
      card: card,
      now: now,
      onTap: () => openCard(context, card),
    );
  }
}

/// The card after Agora, at its hour: play for a task, nothing for a fixed
/// block, which is never begun by hand.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.card});

  final TimelineEvent card;

  @override
  Widget build(BuildContext context) {
    final parent = card.artifactTitle;
    return TaskCard(
      title: parent ?? card.title,
      subtitle: parent == null ? null : card.title,
      trailing: hhmm(card.startTime),
      onPlay: card.isTask && card.isInteractive
          ? () => playCard(context, card)
          : null,
      onTap: () => openCard(context, card),
    );
  }
}

/// A card's room in the column: the page's margin, and a gap under it.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        0,
        AppSpacing.s5,
        AppSpacing.s2,
      ),
      child: child,
    );
  }
}

/// A section's name; Agora's carries the day's mark beside it and the way
/// to the calendar.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.mark, this.action});

  final String title;
  final DayMark? mark;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        action == null ? AppSpacing.s6 : AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          Text(title, style: AppTypography.title),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TodayTag(mark: mark),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// {@template today_tag}
/// What today is beyond its hours, as one tag: the day of the cycle and
/// what the day is ("Dia 2 · dia leve"), or its phase on a working day;
/// without a cycle, the day's own tag ("Folga"); on a plain working day,
/// nothing.
/// {@endtemplate}
class TodayTag extends StatelessWidget {
  /// {@macro today_tag}
  const TodayTag({required this.mark, super.key});

  /// Today's mark.
  final DayMark? mark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mark = this.mark;
    final day = mark?.cycleDay;
    final phase = mark?.phase;
    if (mark != null && day != null && phase != null) {
      return AppTag(
        text: l10n.homeCycleTag(day, switch (mark.kind) {
          DayKind.light => l10n.dayLightShort,
          DayKind.off => l10n.dayOffShort,
          DayKind.work => phase.label(l10n),
        }),
        iconData: phase.icon,
        fill: phase.fill,
        ink: phase.ink,
      );
    }
    if (mark != null && mark.restricted) return DayMarkTag(mark: mark);
    return const SizedBox.shrink();
  }
}

/// The row under Para depois's four that opens the whole queue.
class _OpenRow extends StatelessWidget {
  const _OpenRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.labelStrong.copyWith(
                  color: AppColors.ink2,
                ),
              ),
            ),
            const AppIcon(
              iconData: AppIcons.chevronRight,
              size: AppSpacing.s4,
              color: AppColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// A section with nothing in it, said in a line.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(text, style: AppTypography.label),
    );
  }
}
