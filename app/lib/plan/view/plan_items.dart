import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// The room between two cards of Plano (Agora, Em seguida, Pendentes and
/// Para depois) and of Para depois's own page: one spacing everywhere, so
/// each section reads as one list.
const double kQueueGap = AppSpacing.s1;

/// {@template plan_items}
/// What Plano draws, worked out from the day ([TimelineState]) and the
/// deliveries ([ArtifactsData]): one kind of task, whether it has tasks of
/// its own (a delivery) or not.
///
/// - [now], the card on Agora, and [next], the first card after it.
/// - [pending]: every task begun and not finished, which today means a
///   delivery begun ([isStarted]), the most urgent first as Entregas put
///   them. The one whose task runs on Agora is left out: it is drawn
///   there.
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
    final next = day.cards
        .where((card) => card.section == TimelineSection.dia && card != agora)
        .firstOrNull;
    final groups = progressGroups(deliveries?.queue ?? const [], now);
    final running = agora?.artifactId;

    return PlanItems._(
      now: agora,
      next: next,
      pending: [
        for (final a in groups.started)
          if (a.id != running) a,
      ],
      later: [
        for (final task in day.backlog)
          if (task.artifactId == null) LaterTask(task),
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

  /// The first card after Agora.
  final TimelineEvent? next;

  /// The tasks begun and not finished, Agora's left out.
  final List<Artifact> pending;

  /// Every task not begun, in order.
  final List<Later> later;
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

/// Plays a task that waits: the same as letting it go on Agora.
void playCard(BuildContext context, TimelineEvent card) {
  context.read<TimelineBloc>().add(
    EventMoved(id: card.id, index: 0, start: true),
  );
}

/// {@template pending_card}
/// A task begun and not finished, drawn as Agora is: play on the left (its
/// next task begins), where it stands under the name (its time done of the
/// whole, and its day, in red once urgent) with −10, +10 and ✓ beside it,
/// and its bar under it: the time gone in red under the work done in green.
/// {@endtemplate}
class PendingCard extends StatelessWidget {
  /// {@macro pending_card}
  const PendingCard({required this.artifact, required this.now, super.key});

  /// The task with tasks.
  final Artifact artifact;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = artifact;
    final cubit = context.read<ArtifactsCubit>();
    final due = a.deadline == null
        ? null
        : isOverdue(a, now)
        ? remainingLabel(l10n, a, now)
        : deadlineLabel(l10n, a, now);
    final floor = a.doneMinutes < stepMinutes ? stepMinutes : a.doneMinutes;

    return TaskCard(
      title: a.title,
      subtitle: nextTaskOf(a)?.title,
      onPlay: () =>
          context.read<TimelineBloc>().add(ArtifactPlayed(artifact.id)),
      status: [
        l10n.artifactTimeDone(
          formatMinutes(l10n, a.doneMinutes),
          formatMinutes(l10n, a.minutes),
        ),
        ?due,
      ].join(' · '),
      statusInk: isUrgent(a, now) ? AppColors.dangerInk : null,
      controls: true,
      onLess: a.minutes - stepMinutes < floor
          ? null
          : () => unawaited(cubit.addMinutes(a.id, -stepMinutes)),
      onMore: () => unawaited(cubit.addMinutes(a.id, stepMinutes)),
      onDone: () => unawaited(cubit.setDone(a.id, done: true)),
      bar: TaskBar(done: workDone(a), time: a.progressAt(now)),
      onTap: () => unawaited(openArtifact(context, a.id, tab: 1)),
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
          onPlay: () => playCard(context, card),
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
          onPlay: () =>
              context.read<TimelineBloc>().add(ArtifactPlayed(artifact.id)),
          onTap: () => unawaited(openArtifact(context, artifact.id, tab: 1)),
        );
    }
  }
}
