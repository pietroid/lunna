import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_drag.dart';
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
/// Agora. The running one's is pause. Held, any task (not a fixed block)
/// can be carried between Agora, Em seguida, Pendentes and Para depois
/// ([dropOnPlan]); while one is, Pendentes is drawn even when empty.
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

  /// Whether a card is being carried.
  bool _carrying = false;
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

  void _setCarrying(bool carrying) {
    if (mounted && carrying != _carrying) {
      setState(() => _carrying = carrying);
    }
  }

  /// [child], the card of [card], made something to carry when it is a
  /// task (a fixed block is never moved by hand).
  Widget _carry(TimelineEvent? card, PlanSection from, Widget child) {
    if (card == null || !card.isTask || !card.isInteractive) return child;
    return PlanDraggable(
      carry: CarryCard(card, from),
      onCarry: _setCarrying,
      child: child,
    );
  }

  /// A card of Pendentes, to carry.
  Widget _pending(Pending item, DateTime now) {
    return switch (item) {
      PendingDelivery(:final artifact) => PlanDraggable(
        carry: CarryDelivery(artifact, PlanSection.pending),
        onCarry: _setCarrying,
        child: PendingCard(artifact: artifact, now: now),
      ),
      PendingTask(:final card) => PlanDraggable(
        carry: CarryCard(card, PlanSection.pending),
        onCarry: _setCarrying,
        child: PendingTaskCard(card: card),
      ),
    };
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
                      PlanDropTarget(
                        section: PlanSection.now,
                        onDrop: planDropper(context, PlanSection.now, items),
                        builder: (context, {required hovering}) => _Pad(
                          child: NowDropZone(
                            hovering: hovering,
                            child: _carry(
                              items.now,
                              PlanSection.now,
                              _NowCard(card: items.now, now: now),
                            ),
                          ),
                        ),
                      ),
                      if (items.next case final next?)
                        PlanDropTarget(
                          section: PlanSection.next,
                          onDrop: planDropper(context, PlanSection.next, items),
                          builder: (context, {required hovering}) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              if (hovering) const _Pad(child: PlanDropGap()),
                              _Pad(
                                child: _carry(
                                  next,
                                  PlanSection.next,
                                  _NextCard(card: next),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (items.pending.isNotEmpty || _carrying)
                        PlanDropTarget(
                          section: PlanSection.pending,
                          onDrop: planDropper(
                            context,
                            PlanSection.pending,
                            items,
                          ),
                          builder: (context, {required hovering}) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Heading(title: l10n.homePending),
                              if (hovering) const _Pad(child: PlanDropGap()),
                              for (final item in items.pending)
                                _Pad(
                                  key: ValueKey(item.id),
                                  child: _pending(item, now),
                                ),
                            ],
                          ),
                        ),
                      PlanDropTarget(
                        section: PlanSection.later,
                        onDrop: planDropper(context, PlanSection.later, items),
                        builder: (context, {required hovering}) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Heading(title: l10n.stageBacklog),
                            if (hovering) const _Pad(child: PlanDropGap()),
                            if (later.isEmpty && !hovering)
                              _Pad(child: _Quiet(text: l10n.homeLaterEmpty)),
                            for (final item in later)
                              _Pad(
                                key: ValueKey(item.id),
                                child: PlanDraggable(
                                  carry: switch (item) {
                                    LaterTask(:final card) => CarryCard(
                                      card,
                                      PlanSection.later,
                                    ),
                                    LaterDelivery(:final artifact) =>
                                      CarryDelivery(
                                        artifact,
                                        PlanSection.later,
                                      ),
                                  },
                                  onCarry: _setCarrying,
                                  child: LaterCard(item: item, now: now),
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
  const _Pad({required this.child, super.key});

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

/// {@template now_drop_zone}
/// Agora while a card is carried over it: what runs fades under an
/// accent outline that says letting go begins the card. Pendentes, Em
/// seguida and Para depois open a gap at their top ([PlanDropGap]); only
/// Agora says what a drop does, since only there it starts something.
/// {@endtemplate}
class NowDropZone extends StatelessWidget {
  /// {@macro now_drop_zone}
  const NowDropZone({required this.hovering, required this.child, super.key});

  /// Whether a card is over it.
  final bool hovering;

  /// Agora's card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hovering) return child;
    final radius = BorderRadius.circular(AppSpacing.chipRadius);
    return Stack(
      children: [
        Opacity(opacity: 0.25, child: child),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.6),
              borderRadius: radius,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    iconData: AppIcons.play,
                    size: AppSpacing.s4,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    context.l10n.planDropStart,
                    style: AppTypography.labelStrong.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
