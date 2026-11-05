import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/play_sheet.dart';
import 'package:timeline/timeline.dart';

/// The room between two cards of Plano (Agora, Em seguida, Pendentes and
/// Para depois): one spacing everywhere, so each section reads as one
/// list.
const double kQueueGap = AppSpacing.s1;

/// {@template plan_items}
/// What Plano draws, worked out from the day ([TimelineState]) and the
/// deliveries ([ArtifactsData]): one kind of task, whether it has tasks of
/// its own (a delivery) or not.
///
/// - [now], the card on Agora, and [next], everything after it that has
///   an hour: every card of the first day that has any (today, while it
///   has some left), its events too, then every task the queue puts on
///   the days after it, in their order. No limit: each with the hour the
///   layout gives it, so a pause, a move or a task done earlier moves them
///   all on the next read.
/// - [pending]: every task begun and not finished: the deliveries begun
///   ([isStarted]), the most urgent first as Entregas put them, then the
///   loose tasks paused off the day ([TimelineEvent.pending]). The
///   delivery whose piece runs on Agora stays (#92): the rest of a task
///   split waits here, and the piece at work is the yellow of its bar.
/// - [later]: everything not begun, in one list: the loose tasks waiting in
///   the backlog, in its order, then the deliveries not begun, in the
///   queue's.
/// {@endtemplate}
class PlanItems {
  /// {@macro plan_items}
  factory PlanItems.of(
    TimelineState day,
    ArtifactsData? deliveries,
    DateTime now,
  ) {
    final agora = day.cards
        .where((card) => card.section == TimelineSection.agora)
        .firstOrNull;
    final after = [
      for (final card in day.cards)
        if (card.section == TimelineSection.dia && card != agora) card,
    ];
    final first = after.firstOrNull;
    final sameDay = [
      for (final card in after)
        if (first != null && _sameDay(card.startTime, first.startTime)) card,
    ];
    final ahead = [
      for (final task in day.tasks)
        if (first != null &&
            !task.started &&
            task != agora &&
            task.startTime.isAfter(first.startTime) &&
            !_sameDay(task.startTime, first.startTime))
          task,
    ];
    final groups = progressGroups(deliveries?.queue ?? const [], now);
    final running = agora?.artifactId;

    return PlanItems._(
      now: agora,
      next: [...sameDay, ...ahead],
      pending: [
        for (final a in groups.started)
          PendingDelivery(
            a,
            doingMinutes: a.id == running ? agora!.workMinutes : 0,
          ),
        for (final task in day.backlog)
          if (task.artifactId == null && task.pending) PendingTask(task),
      ],
      later: [
        for (final task in day.backlog)
          if (task.artifactId == null && !task.pending) LaterTask(task),
        for (final a in groups.waiting)
          if (a.id != running) LaterDelivery(a),
      ],
    );
  }

  const PlanItems._({
    required this.now,
    required this.next,
    required this.pending,
    required this.later,
  });

  /// The card on Agora, or none (the break).
  final TimelineEvent? now;

  /// The queue after Agora, in its order: tasks to play and to carry, and
  /// the fixed blocks between them, which keep their place.
  final List<TimelineEvent> next;

  /// Whether [a] and [b] fall on the same day.
  static bool sameDay(DateTime a, DateTime b) => _sameDay(a, b);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The tasks begun and not finished, Agora's delivery too.
  final List<Pending> pending;

  /// Every task not begun, in order.
  final List<Later> later;
}

/// One task in Pendentes: a delivery begun ([PendingDelivery]) or a loose
/// task paused off the day ([PendingTask]).
sealed class Pending {
  const Pending();

  /// Its id, for keys.
  String get id;
}

/// A delivery begun and not delivered.
final class PendingDelivery extends Pending {
  /// Wraps [artifact].
  const PendingDelivery(this.artifact, {this.doingMinutes = 0});

  /// The delivery.
  final Artifact artifact;

  /// The minutes of its piece at work on Agora, or 0 (#92).
  final int doingMinutes;

  @override
  String get id => artifact.id;
}

/// A loose task begun and paused off the day: it waits in the backlog,
/// owing what it had left.
final class PendingTask extends Pending {
  /// Wraps [card].
  const PendingTask(this.card);

  /// The task, as the day draws it.
  final TimelineEvent card;

  @override
  String get id => card.id;
}

/// One task in Para depois: a loose one ([LaterTask]) or one with tasks of
/// its own ([LaterDelivery]).
sealed class Later {
  const Later();

  /// Its id, for keys.
  String get id;
}

/// A loose task waiting in the backlog.
final class LaterTask extends Later {
  /// Wraps [card].
  const LaterTask(this.card);

  /// The task, as the day draws it.
  final TimelineEvent card;

  @override
  String get id => card.id;
}

/// A delivery not begun.
final class LaterDelivery extends Later {
  /// Wraps [artifact].
  const LaterDelivery(this.artifact);

  /// The delivery.
  final Artifact artifact;

  @override
  String get id => artifact.id;
}

/// The task of [artifact] that comes next: the first the queue reaches,
/// else the first of its backlog. Null when it has nothing left to do.
ArtifactTask? nextTaskOf(Artifact artifact) {
  final open = artifact.tasks.where((t) => t.place != TaskPlace.done);
  final timed = open.where((t) => t.at != null).toList()
    ..sort((a, b) => a.at!.compareTo(b.at!));
  return timed.firstOrNull ?? open.firstOrNull;
}

/// Opens what [card] is: a delivery's task opens the delivery, on what is
/// left to do of it; any other card its own page.
void openCard(BuildContext context, TimelineEvent card) {
  final artifact = card.artifactId;
  if (artifact != null) {
    unawaited(openArtifact(context, artifact, tab: 1));
    return;
  }
  unawaited(context.push<void>('/evento/${Uri.encodeComponent(card.id)}'));
}

/// Plays a task that waits, by play's strict rules (#89): when, the
/// pause, how much ([playTask], in `timeline`). A task already waiting on
/// Agora is next already: it begins ([beginTask]).
Future<void> playCard(BuildContext context, TimelineEvent card) =>
    playTask(context, card);

/// {@template pending_card}
/// A task begun and not finished, drawn as Agora is: play on the left (its
/// next task begins, asking how much first when that is over an hour,
/// [playPending]), and in the corner, where a task with an hour says its
/// hour, the day it is due by ([dueLabel]: "hoje", "quinta-feira",
/// "12/nov", "para ontem"). Under the name, its time done of the whole,
/// the whole being its own time or its tasks' together when they add up
/// to more, with −1d, +1d and ✓ beside it; and its bar: the time gone in
/// red under the work done in green, and the piece at work on Agora, when
/// one is, in yellow right after the green (#92). With no day there is no
/// time: the green alone.
///
/// Past its day it is **urgent**: the card takes the red tint, the corner
/// says "para ontem" in the danger ink, the line says Urgente, and the red
/// runs the whole bar.
/// {@endtemplate}
class PendingCard extends StatelessWidget {
  /// {@macro pending_card}
  const PendingCard({
    required this.artifact,
    required this.now,
    this.doingMinutes = 0,
    this.onPlay,
    super.key,
  });

  /// The task with tasks.
  final Artifact artifact;

  /// The minutes of its piece at work now, drawn yellow; 0 when none.
  final int doingMinutes;

  /// The moment it is drawn at.
  final DateTime now;

  /// Plays it; by default [playPending].
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = artifact;
    final cubit = context.read<ArtifactsCubit>();
    final late = isOverdue(a, now);
    final done = l10n.artifactTimeDone(
      formatMinutes(l10n, a.doneMinutes),
      formatMinutes(l10n, a.minutes),
    );

    return TaskCard(
      title: a.title,
      subtitle: nextTaskOf(a)?.title,
      trailing: dueLabel(l10n, a, now),
      trailingInk: late ? AppColors.dangerInk : null,
      fill: late ? AppColors.urgentFill : null,
      onPlay: onPlay ?? () => unawaited(playPending(context, a)),
      status: late ? l10n.pendingUrgentStatus(done) : done,
      statusInk: late ? AppColors.dangerInk : null,
      controls: true,
      step: TaskStep.days,
      onLess: a.deadline == null
          ? null
          : () => unawaited(cubit.shiftDeadline(a.id, -1)),
      onMore: () => unawaited(cubit.shiftDeadline(a.id, 1)),
      onDone: () => unawaited(cubit.setDone(a.id, done: true)),
      bar: TaskBar(
        done: workDone(a),
        time: a.progressAt(now),
        late: late,
        doing: a.minutes == 0 ? 0 : doingMinutes / a.minutes,
        pace: true,
      ),
      onTap: () => unawaited(openArtifact(context, a.id, tab: 1)),
    );
  }
}

/// {@template pending_task_card}
/// A loose task paused off the day, in Pendentes: play, its name, what it
/// still owes, and −10, +10 and ✓, as Agora draws them. No bar: it has no
/// tasks and no day.
/// {@endtemplate}
class PendingTaskCard extends StatelessWidget {
  /// {@macro pending_task_card}
  const PendingTaskCard({required this.card, super.key});

  /// The task.
  final TimelineEvent card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<TimelineBloc>();
    return TaskCard(
      title: card.title,
      onPlay: () => unawaited(playCard(context, card)),
      status: l10n.pendingTaskLeft(durationLabel(l10n, card.workMinutes)),
      controls: true,
      onLess: card.canShorten(stepMinutes, clock.now())
          ? () => unawaited(adjustTime(context, card, -stepMinutes))
          : null,
      onMore: () => unawaited(adjustTime(context, card, stepMinutes)),
      onDone: () => bloc.add(EventFinished(card.id)),
      onTap: () => openCard(context, card),
    );
  }
}

/// {@template later_card}
/// A task not begun, in Para depois: play, its name, what it is (its
/// product and how many tasks it has, or its day) and its length. No bar
/// and no controls: nothing of it runs yet.
/// {@endtemplate}
class LaterCard extends StatelessWidget {
  /// {@macro later_card}
  const LaterCard({required this.item, required this.now, super.key});

  /// The task.
  final Later item;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (item) {
      case LaterTask(:final card):
        return TaskCard(
          title: card.title,
          trailing: durationLabel(l10n, card.durationMinutes),
          onPlay: () => unawaited(playCard(context, card)),
          onTap: () => openCard(context, card),
        );
      case LaterDelivery(:final artifact):
        final open = artifact.steps - artifact.stepsDone;
        final what = [
          ?artifact.type?.name,
          if (open > 0) l10n.taskTasksCount(open),
          if (artifact.deadline != null) deadlineLabel(l10n, artifact, now),
        ];
        return TaskCard(
          title: artifact.title,
          subtitle: what.isEmpty ? null : what.join(' · '),
          trailing: artifact.minutes > 0
              ? formatMinutes(l10n, artifact.minutes)
              : null,
          onPlay: () => unawaited(playPending(context, artifact)),
          onTap: () => unawaited(openArtifact(context, artifact.id, tab: 1)),
        );
    }
  }
}
