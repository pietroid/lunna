import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/view/greeting.dart';
import 'package:lunna/panel/panel.dart';
import 'package:timeline/timeline.dart';

/// {@template overview_page}
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
/// {@endtemplate}
class OverviewPage extends StatelessWidget {
  /// {@macro overview_page}
  const OverviewPage({
    required this.onOpen,
    this.firstName,
    this.onProfile,
    this.controller,
    super.key,
  });

  /// The person's first name, for the greeting.
  final String? firstName;

  /// Brings a tab of Plano forward. [PanelTab.calendar] opens Tarefas on
  /// the calendar.
  final ValueChanged<PanelTab> onOpen;

  /// The account menu behind the greeting (Rotina, Sair); without it the
  /// greeting is only a greeting.
  final List<PopupMenuEntry<void>> Function(BuildContext context)? onProfile;

  /// The scroll of the page.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider<SuggestionCubit>(
      create: (context) {
        final cubit = SuggestionCubit(
          repository: context.read<AgentRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.only(bottom: kNotesDockClearance),
              children: [
                _Header(firstName: firstName, menu: onProfile),
                // The agent's one unasked-for offer, first: it is about the
                // day below it, and goes once taken or turned down.
                const SuggestionCard(),
                _Heading(
                  title: l10n.overviewNow,
                  action: l10n.overviewSeeDay,
                  icon: AppIcons.calendar,
                  onTap: () => onOpen(PanelTab.calendar),
                ),
                const _NowAndNext(),
                _Heading(
                  title: l10n.overviewMainDelivery,
                  action: l10n.overviewSeeDeliveries,
                  icon: AppIcons.artifacts,
                  onTap: () => onOpen(PanelTab.deliveries),
                ),
                const _MainDelivery(),
                _Heading(
                  title: l10n.overviewMainGoal,
                  action: l10n.overviewSeeGoals,
                  icon: AppIcons.goal,
                  onTap: () => onOpen(PanelTab.goals),
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
            _Quiet(text: context.l10n.overviewBreak)
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
                context.l10n.overviewNext,
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
          ? _Quiet(text: context.l10n.overviewNoDelivery)
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
          ? _Quiet(text: context.l10n.overviewNoGoal)
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
