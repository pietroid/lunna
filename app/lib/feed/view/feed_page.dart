import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/feed/view/greeting.dart';
import 'package:lunna/plan/plan.dart';
import 'package:timeline/timeline.dart';

/// {@template feed_page}
/// The Feed tab: what to do now, at a glance, and a way into each level
/// of Plano.
///
/// From the top: who you are and what time it is; the agent's one offer
/// ([SuggestionCard]); **Agora**, the block being lived through with its
/// own controls, and under it the one that follows; the **main delivery**,
/// the one Entregas puts first; and the **goal** being measured. Each
/// section's heading ends in the place in Plano it summarises (the day on
/// the calendar, Entregas, Objetivos), and each card opens what it is, as it
/// does in Plano.
///
/// Nothing here is a list. It is one of each, chosen the way Plano already
/// orders them, so the screen stays the same size whatever the day holds.
///
/// The offer is asked for again each time the tab comes to the front
/// ([shown]) and when a new day begins, since it is about the day.
/// {@endtemplate}
class FeedPage extends StatefulWidget {
  /// {@macro feed_page}
  const FeedPage({
    required this.onOpen,
    this.shown = true,
    this.firstName,
    this.onProfile,
    this.controller,
    super.key,
  });

  /// The person's first name, for the greeting.
  final String? firstName;

  /// Brings a tab of Plano forward. [PlanTab.calendar] opens Tarefas on
  /// the calendar.
  final ValueChanged<PlanTab> onOpen;

  /// Whether the tab is in front. Brought forward, it asks for the offer
  /// again; behind, it asks nothing.
  final bool shown;

  /// The account menu behind the greeting (Rotina, Sair); without it the
  /// greeting is only a greeting.
  final List<PopupMenuEntry<void>> Function(BuildContext context)? onProfile;

  /// The scroll of the page.
  final ScrollController? controller;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
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
  void didUpdateWidget(FeedPage oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider<SuggestionCubit>.value(
      value: _suggestion,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: ListView(
              controller: widget.controller,
              // The bottom bar, which the body runs under, comes in the
              // padding; the dock floats over it.
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.paddingOf(context).bottom + kNotesDockClearance,
              ),
              children: [
                _Header(firstName: widget.firstName, menu: widget.onProfile),
                // The agent's one unasked-for offer, first: it is about the
                // day below it, and goes once taken or turned down.
                const SuggestionCard(),
                _Heading(
                  title: l10n.feedNow,
                  action: l10n.feedSeeDay,
                  icon: AppIcons.calendar,
                  onTap: () => widget.onOpen(PlanTab.calendar),
                ),
                const _NowAndNext(),
                _Heading(
                  title: l10n.feedMainDelivery,
                  action: l10n.feedSeeDeliveries,
                  icon: AppIcons.artifacts,
                  onTap: () => widget.onOpen(PlanTab.deliveries),
                ),
                const _MainDelivery(),
                _Heading(
                  title: l10n.feedMainGoal,
                  action: l10n.feedSeeGoals,
                  icon: AppIcons.goal,
                  onTap: () => widget.onOpen(PlanTab.goals),
                ),
                const _MainGoal(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The greeting, the date, and the ring of the working day.
class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.menu});

  final String? firstName;
  final List<PopupMenuEntry<void>> Function(BuildContext context)? menu;

  @override
  Widget build(BuildContext context) {
    final workDay = context.select<TimelineBloc, WorkDay>(
      (bloc) => bloc.state.workDay,
    );
    final menu = this.menu;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s5,
      ),
      child: AppMinuteBuilder(
        builder: (context, now) {
          final hello = Text(
            greeting(context.l10n, now, firstName),
            style: AppTypography.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The greeting is the account: the only thing that
                    // names the person opens their menu.
                    if (menu == null)
                      hello
                    else
                      PopupMenuButton<void>(
                        padding: EdgeInsets.zero,
                        tooltip: '',
                        offset: const Offset(0, AppSpacing.s8),
                        itemBuilder: menu,
                        child: hello,
                      ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      longDate(context.l10n, now),
                      style: AppTypography.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              AppDayClock(
                startHour: workDay.start / 60,
                endHour: workDay.end / 60,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A section's name, and the way to the place in Plano it summarises.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.action,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String action;
  final AppIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s2,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.title)),
          AppPillButton(label: action, iconData: icon, onPressed: onTap),
        ],
      ),
    );
  }
}

/// What is being lived through, with its controls, and what comes after.
///
/// Agora is the card the timeline puts in its first stage, drawn by the
/// same tile with the same buttons; the next is the first card after it,
/// task or fixed block, since what follows is what the person plans around.
class _NowAndNext extends StatelessWidget {
  const _NowAndNext();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TimelineBloc>();
    final cards = context.select<TimelineBloc, List<TimelineEvent>>(
      (bloc) => bloc.state.cards,
    );
    final now = cards
        .where(
          (card) => card.section == TimelineSection.agora,
        )
        .firstOrNull;
    final next = cards
        .where(
          (card) => card.section == TimelineSection.dia && card != now,
        )
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (now == null)
            _Quiet(text: context.l10n.feedBreak)
          else
            EventTile(
              card: now,
              onPauseToggled: () => bloc.add(EventPauseToggled(now.id)),
              onAdjusted: (minutes) =>
                  unawaited(adjustTime(context, now, minutes)),
              onDone: () => bloc.add(EventFinished(now.id)),
              onStarted: () => bloc.add(EventStarted(now.id)),
              onSnoozed: () => bloc.add(EventSnoozed(now.id)),
            ),
          if (next != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s1,
                AppSpacing.s4,
                0,
                AppSpacing.s2,
              ),
              child: Text(
                context.l10n.feedNext,
                style: AppTypography.caption,
              ),
            ),
            EventTile(card: next),
          ],
        ],
      ),
    );
  }
}

/// The delivery Entregas puts first: the most urgent of those under way,
/// else the first of the queue.
class _MainDelivery extends StatelessWidget {
  const _MainDelivery();

  @override
  Widget build(BuildContext context) {
    final data = context.select<ArtifactsCubit, ArtifactsData?>(
      (cubit) => cubit.state.data,
    );
    final now = clock.now();
    final groups = progressGroups(data?.queue ?? const [], now);
    final main = groups.started.firstOrNull ?? groups.waiting.firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      child: main == null
          ? _Quiet(text: context.l10n.feedNoDelivery)
          : ArtifactRow(
              artifact: main,
              now: now,
              onTap: () => unawaited(openArtifact(context, main.id, tab: 1)),
            ),
    );
  }
}

/// The goal being measured now, as Objetivos draws it on top.
class _MainGoal extends StatelessWidget {
  const _MainGoal();

  @override
  Widget build(BuildContext context) {
    final data = context.select<ArtifactsCubit, ArtifactsData?>(
      (cubit) => cubit.state.data,
    );
    final now = clock.now();
    final goal = data?.goals
        .where(
          (goal) =>
              goal.kind == GoalKind.money &&
              goal.isActiveAt(now) &&
              !goal.isOverAt(now),
        )
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      child: goal == null
          ? _Quiet(text: context.l10n.feedNoGoal)
          : GoalCard(
              goal: goal,
              now: now,
              onTap: () => unawaited(showGoalSheet(context, goal: goal)),
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
