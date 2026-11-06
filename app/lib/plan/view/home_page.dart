import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_drag.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:lunna/plan/view/plan_skeleton.dart';
import 'package:lunna/plan/view/plan_swipe.dart';
import 'package:lunna/plan/view/write_task.dart';
import 'package:lunna/tempo/view/minute_refresh.dart';
import 'package:lunna/tempo/view/tempo_page.dart';
import 'package:timeline/timeline.dart';

/// Whether Plano draws the agent's offer. Off for now (#79): the card and
/// its cubit stay, so turning it back on is this line.
const kSuggestionOnPlan = false;

/// {@template home_page}
/// Plano: what to do now, what is under way, and what comes later.
///
/// No greeting and no clock. From the top: the agent's one offer, as it
/// was; **Agora**, with the day's mark beside its heading (the cycle, a
/// light day, a day off), the running task; **Em seguida**, with *Ver
/// calendário* beside its heading ([onSeeDay]), everything after it that
/// has an hour, with no limit, and *+ Adicionar*; **Pendentes**, every
/// task begun and not finished, drawn as Agora is, with −10, +10 and ✓
/// and its bar under it; **Para depois**, the whole of it, and *+
/// Adicionar*. Until the day first arrives, each section is drawn as its
/// cards' skeleton ([PlanSkeletonCard]), never an empty page.
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
    this.shown = true,
    this.controller,
    super.key,
  });

  /// Opens the calendar.
  final VoidCallback onSeeDay;

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
    if (widget.shown && kSuggestionOnPlan) _ask();
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kSuggestionOnPlan && widget.shown && !oldWidget.shown) _ask();
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
    if (!mounted || !widget.shown || !kSuggestionOnPlan) return;
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
  ///
  /// A task is also swiped: right is done, left is deleted, each asked
  /// first ([PlanSwipe]).
  Widget _carry(TimelineEvent? card, PlanSection from, Widget child) {
    if (card == null || !card.isTask || !card.isInteractive) return child;
    return PlanSwipe.task(
      card: card,
      child: PlanDraggable(
        carry: CarryCard(card, from),
        onCarry: _setCarrying,
        child: child,
      ),
    );
  }

  /// A card of Pendentes, to carry and to swipe.
  Widget _pending(Pending item, DateTime now) {
    return switch (item) {
      PendingDelivery(:final artifact, :final doingMinutes) =>
        PlanSwipe.delivery(
          artifact: artifact,
          child: PlanDraggable(
            carry: CarryDelivery(artifact, PlanSection.pending),
            onCarry: _setCarrying,
            child: PendingCard(
              artifact: artifact,
              now: now,
              doingMinutes: doingMinutes,
            ),
          ),
        ),
      PendingTask(:final card) => _carry(
        card,
        PlanSection.pending,
        PendingTaskCard(card: card),
      ),
    };
  }

  /// A card of Para depois, to carry and to swipe.
  Widget _later(Later item, DateTime now) {
    final drawn = LaterCard(item: item, now: now);
    return switch (item) {
      LaterTask(:final card) => _carry(card, PlanSection.later, drawn),
      LaterDelivery(:final artifact) => PlanSwipe.delivery(
        artifact: artifact,
        child: PlanDraggable(
          carry: CarryDelivery(artifact, PlanSection.later),
          onCarry: _setCarrying,
          child: drawn,
        ),
      ),
    };
  }

  /// Plano before the day first arrives: each section's heading and its
  /// cards' skeleton, where they will be.
  List<Widget> _skeleton(BuildContext context) {
    final l10n = context.l10n;
    return [
      const _Pad(child: PlanSkeletonCard(tall: true)),
      _Heading(
        title: l10n.feedNext,
        action: AppPillButton(
          label: l10n.homeSeeCalendar,
          iconData: AppIcons.calendar,
          onPressed: widget.onSeeDay,
        ),
      ),
      for (final width in const [0.6, 0.45, 0.7, 0.5])
        _Pad(child: PlanSkeletonCard(title: width)),
      _Heading(title: l10n.stageBacklog),
      for (final width in const [0.5, 0.65, 0.4])
        _Pad(child: PlanSkeletonCard(title: width)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = context.watch<TimelineBloc>().state;
    final deliveries = context.watch<ArtifactsCubit>().state.data;
    final now = clock.now();
    final items = PlanItems.of(day, deliveries, now);
    final guard = day.guard;
    final later = items.later;
    // The first read only: a reload keeps the cards on screen.
    final loading = day.status == TimelineStatus.initial || day.isInitialLoad;

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
                      if (kSuggestionOnPlan) const SuggestionCard(),
                      _Heading(title: l10n.feedNow, mark: day.marks.on(now)),
                      if (loading)
                        ..._skeleton(context)
                      else ...[
                        PlanDropTarget(
                          section: PlanSection.now,
                          onDrop: planDropper(context, PlanSection.now, items),
                          builder: (context, {hovering}) => _Pad(
                            child: NowDropZone(
                              hovering: hovering,
                              child: _carry(
                                items.now,
                                PlanSection.now,
                                _NowCard(card: items.now, day: day, now: now),
                              ),
                            ),
                          ),
                        ),
                        // Em seguida is a heading as Agora is, and a queue:
                        // every task plays, and is carried to another place
                        // in it or to another section.
                        _Heading(
                          title: l10n.feedNext,
                          action: AppPillButton(
                            label: l10n.homeSeeCalendar,
                            iconData: AppIcons.calendar,
                            onPressed: widget.onSeeDay,
                          ),
                        ),
                        // Kept while a card is carried, so nothing under
                        // the finger moves; the card's copy opens under it.
                        if (items.next.isEmpty)
                          _Pad(child: _Quiet(text: l10n.homeNextEmpty)),
                        PlanQueue<TimelineEvent>(
                          items: items.next,
                          idOf: (card) => card.id,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s6,
                            0,
                            AppSpacing.s6,
                            kQueueGap,
                          ),
                          onDrop: queueDropper(context, items),
                          itemBuilder: (context, card) => _DayOf(
                            card: card,
                            cards: items.next,
                            now: now,
                            child: _carry(
                              card,
                              PlanSection.next,
                              _NextCard(card: card),
                            ),
                          ),
                        ),
                        // The queue ends in a +, as Lista's day did: it
                        // writes a task right after the last one here.
                        _Pad(
                          child: AppAddRow(
                            dense: true,
                            onTap: () => unawaited(
                              writeTask(
                                context,
                                placement: Placement.queue(
                                  queueEndOf(day.tasks, items),
                                ),
                              ),
                            ),
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
                            builder: (context, {hovering}) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Heading(title: l10n.homePending),
                                if (hovering != null)
                                  _Pad(child: PlanDropGhost(carry: hovering)),
                                for (final item in items.pending)
                                  _Pad(
                                    key: ValueKey(item.id),
                                    child: _pending(item, now),
                                  ),
                              ],
                            ),
                          ),
                        // Para depois is a queue as Em seguida is: a card
                        // let go before another takes its place, so it is
                        // reordered by hand. Let go on the heading, it goes
                        // first.
                        PlanDropTarget(
                          section: PlanSection.later,
                          onDrop: (carry) => unawaited(
                            dropOnPlan(
                              context,
                              carry,
                              PlanSection.later,
                              items,
                              beforeLater: later.firstOrNull,
                            ),
                          ),
                          builder: (context, {hovering}) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Heading(title: l10n.stageBacklog),
                              if (hovering != null)
                                _Pad(child: PlanDropGhost(carry: hovering)),
                              if (later.isEmpty && hovering == null)
                                _Pad(child: _Quiet(text: l10n.homeLaterEmpty)),
                              PlanQueue<Later>(
                                items: later,
                                idOf: (item) => item.id,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.s5,
                                  0,
                                  AppSpacing.s5,
                                  kQueueGap,
                                ),
                                onDrop: laterDropper(context, items),
                                itemBuilder: (context, item) =>
                                    _later(item, now),
                              ),
                              // Para depois has no limit, and ends as Em
                              // seguida does: room to aim at, then a + that
                              // writes at its end.
                              _Pad(
                                child: AppAddRow(
                                  dense: true,
                                  onTap: () => unawaited(writeTask(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

/// Agora: [NowTaskCard], or, when nothing is in it, what the calendar's
/// Agora says then ([AgoraIdleTile]): the break with its line inside the
/// working day, the day over (or not begun) outside it.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.card, required this.day, required this.now});

  final TimelineEvent? card;
  final TimelineState day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    if (card == null) {
      return AgoraIdleTile(
        workDay: day.workDay,
        now: now,
        nextStart: day.cards
            .where((c) => c.startTime.isAfter(now))
            .map((c) => c.startTime)
            .firstOrNull,
        onWriteDown: (placement) =>
            unawaited(writeTask(context, placement: placement)),
        onAdjustDay: context.read<OpenDayHours?>()?.open,
      );
    }
    return NowTaskCard(
      card: card,
      now: now,
      onTap: () => openCard(context, card),
    );
  }
}

/// The card after Agora, from its start to its end, with play for a task;
/// a fixed block, which begins at its hour by itself, keeps the button's
/// room so its title lines up.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.card});

  final TimelineEvent card;

  @override
  Widget build(BuildContext context) {
    final parent = card.artifactTitle;
    // An event is drawn as the calendar draws it: its own fill and its pin
    // (a routine's day, its repeat) where a task's play would be.
    final (fill, mark, ink) = card.isTask
        ? (null, null, null)
        : card.isRoutine
        ? (AppColors.routineFill, AppIcons.repeat, AppColors.routineInk)
        : (AppColors.fixedFill, AppIcons.pin, AppColors.fixedInk);
    return TaskCard(
      title: parent ?? card.title,
      subtitle: parent == null ? null : card.title,
      trailing: '${hhmm(card.startTime)} – ${hhmm(card.endTime)}',
      fill: fill,
      mark: mark,
      markInk: ink,
      onPlay: card.isTask ? () => unawaited(playCard(context, card)) : null,
      keepPlaySlot: true,
      onTap: () => openCard(context, card),
    );
  }
}

/// A card's room in the column: the page's margin, and under it the gap
/// every card of Plano keeps ([kQueueGap]).
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
        kQueueGap,
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

/// {@template day_of}
/// A card of Em seguida, under its day's name when it is the first card of
/// a day after the first one drawn ("Amanhã", "Sexta, 6 de nov."): the
/// queue runs on into the following days, each task at its hour.
/// {@endtemplate}
class _DayOf extends StatelessWidget {
  const _DayOf({
    required this.card,
    required this.cards,
    required this.now,
    required this.child,
  });

  final TimelineEvent card;
  final List<TimelineEvent> cards;
  final DateTime now;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final i = cards.indexOf(card);
    final first =
        i <= 0 || !PlanItems.sameDay(cards[i - 1].startTime, card.startTime);
    if (i <= 0 || !first || PlanItems.sameDay(card.startTime, now)) {
      return child;
    }
    final l10n = context.l10n;
    final today = DateTime(now.year, now.month, now.day);
    final at = card.startTime;
    final days = DateTime(at.year, at.month, at.day).difference(today).inDays;
    final date = l10n.sectionDay(at);
    final label = days == 1
        ? l10n.sectionTomorrow
        : date.isEmpty
        ? date
        : date[0].toUpperCase() + date.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s1,
            AppSpacing.s3,
            0,
            AppSpacing.s2,
          ),
          child: Text(
            label,
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        child,
      ],
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
/// Agora while a card is carried over it: the card it would begin, quiet
/// ([PlanDropGhost]), in place of what runs, which keeps its room so
/// nothing under it jumps. No words: as everywhere on Plano, the preview
/// is the card where it would land.
/// {@endtemplate}
class NowDropZone extends StatelessWidget {
  /// {@macro now_drop_zone}
  const NowDropZone({required this.hovering, required this.child, super.key});

  /// The card carried over it, or none.
  final PlanCarry? hovering;

  /// Agora's card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final carried = hovering;
    if (carried == null) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility.maintain(visible: false, child: child),
        PlanDropGhost(carry: carried),
      ],
    );
  }
}
