import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/plan_items.dart';
import 'package:lunna/plan/view/play_sheet.dart';
import 'package:timeline/timeline.dart';

/// The four sections of Plano a card can be carried between.
enum PlanSection {
  /// Agora: letting go here is play.
  now,

  /// Em seguida: the next thing after Agora.
  next,

  /// Pendentes: begun and not finished.
  pending,

  /// Para depois: not begun.
  later,
}

/// {@template plan_carry}
/// What a card on Plano carries while it is held: a task of the day or of
/// the backlog ([CarryCard]), or a delivery ([CarryDelivery]), and the
/// section it was picked up from.
/// {@endtemplate}
sealed class PlanCarry {
  /// {@macro plan_carry}
  const PlanCarry(this.from);

  /// Where it was picked up.
  final PlanSection from;

  /// Its id: the card's or the delivery's.
  String get id;

  /// Its name, for the card under the finger.
  String get title;
}

/// A task: the one on Agora, Em seguida, a loose one paused in Pendentes or
/// waiting in Para depois.
final class CarryCard extends PlanCarry {
  /// Carries [card] from [from].
  const CarryCard(this.card, super.from);

  /// The task.
  final TimelineEvent card;

  @override
  String get id => card.id;

  @override
  String get title => card.artifactTitle ?? card.title;
}

/// A delivery: begun, in Pendentes, or not, in Para depois.
final class CarryDelivery extends PlanCarry {
  /// Carries [artifact] from [from].
  const CarryDelivery(this.artifact, super.from);

  /// The delivery.
  final Artifact artifact;

  @override
  String get id => artifact.id;

  @override
  String get title => artifact.title;
}

/// What letting [carry] go on [to] does. Its own section takes nothing.
///
/// - **Agora** is play: a task is a drop at the top of the day
///   (`start: true`, and the guard asks when something else runs); a
///   delivery is [playPending], which asks how much first when that is
///   over an hour.
/// - **Em seguida** is a queue: the task (or a delivery's next task) takes
///   the place it was let go at, [before] that card, or after the last one
///   drawn when [before] is null. A card of Em seguida let go in it again
///   is a reorder.
/// - **Pendentes** takes a loose task off the day, begun: it waits there
///   owing what it had left. A delivery's task goes back to its
///   delivery's backlog, and a delivery not begun is begun (its day asked
///   when it has none).
/// - **Para depois** puts a task in the backlog, stopped and not pending,
///   and stops a delivery begun.
///
/// Out of Agora never asks: what it means is clear from where it lands.
Future<void> dropOnPlan(
  BuildContext context,
  PlanCarry carry,
  PlanSection to,
  PlanItems items, {
  TimelineEvent? before,
}) async {
  if (carry.from == to && to != PlanSection.next) return;
  final bloc = context.read<TimelineBloc>();
  final deliveries = context.read<ArtifactsCubit>();

  switch ((carry, to)) {
    case (CarryCard(:final card), PlanSection.now):
      // Let go on Agora is now: a task over an hour asks how much first.
      await beginCard(context, card);
    case (CarryDelivery(:final artifact), PlanSection.now):
      await playPending(context, artifact);

    case (CarryCard(:final card), PlanSection.next):
      if (card.id == before?.id) return;
      final index = _placeIn(bloc.state.tasks, items, card.id, before);
      // Over an hour, how much goes there (#87), as play asks. A task
      // begun owes what it owes, whole.
      int? minutes;
      if (!card.started && card.isTask && card.workMinutes > kPlayAsksOver) {
        final choice = await PlaceSheet.show(
          context,
          PlaceSheet(
            title: card.title,
            owed: card.workMinutes,
            at: slotHourOf(items, before),
          ),
        );
        switch (choice) {
          case PlayPiece(minutes: final m):
            minutes = m;
          case PlayWhole():
            break;
          case _:
            return;
        }
      }
      // A piece is split off, the rest staying where it was.
      bloc.add(
        EventMoved(
          id: card.id,
          index: index,
          minutes: minutes,
          split: minutes != null,
        ),
      );
    case (CarryDelivery(:final artifact), PlanSection.next):
      final task = nextTaskOf(artifact);
      if (task == null) return;
      final index = _placeIn(bloc.state.tasks, items, task.id, before);
      bloc.add(EventMoved(id: task.id, index: index));

    case (CarryCard(:final card), PlanSection.pending):
      final parent = card.artifactId;
      bloc.add(
        EventMoved(
          id: card.id,
          index: 0,
          backlog: true,
          pending: parent == null,
        ),
      );
      final artifact = parent == null ? null : deliveries.state.byId(parent);
      if (artifact != null && !isStarted(artifact) && context.mounted) {
        await _begin(context, artifact);
      }
    case (CarryDelivery(:final artifact), PlanSection.pending):
      await _begin(context, artifact);

    case (CarryCard(:final card), PlanSection.later):
      bloc.add(EventMoved(id: card.id, index: 0, backlog: true));
    case (CarryDelivery(:final artifact), PlanSection.later):
      if (isStarted(artifact)) await deliveries.stop(artifact.id, 0);
  }
}

/// The hour a drop in Em seguida [before] a card lands at: the end of the
/// card above it (or of Agora's) and the pause.
DateTime slotHourOf(PlanItems items, TimelineEvent? before) {
  final above = before == null
      ? items.next.lastOrNull
      : items.next.takeWhile((c) => c.id != before.id).lastOrNull;
  final end = (above ?? items.now)?.endTime ?? clock.now();
  return end.add(TimelinePlan.gap);
}

/// The place in the list of tasks ([tasks], the day's) that a drop in Em
/// seguida [before] a card means, counted with [id] taken out, as a move
/// counts: that task's place, or right after the last task of Em seguida
/// above it (a fixed block has no place in the queue), or right under
/// what runs on Agora when there is none.
int _placeIn(
  List<TimelineEvent> tasks,
  PlanItems items,
  String id,
  TimelineEvent? before,
) {
  final rest = [
    for (final t in tasks)
      if (t.id != id) t,
  ];
  if (before != null && before.isTask) {
    final i = rest.indexWhere((t) => t.id == before.id);
    if (i >= 0) return i;
  }
  final above = before == null
      ? items.next
      : items.next.takeWhile((c) => c.id != before.id);
  final anchor = above.where((c) => c.isTask && c.id != id).lastOrNull;
  if (anchor != null) {
    final i = rest.indexWhere((t) => t.id == anchor.id);
    if (i >= 0) return i + 1;
  }
  final now = items.now;
  return now != null && now.isTask && now.id != id ? 1 : 0;
}

/// The place in the list of tasks ([tasks]) right after the last task Em
/// seguida draws: where its + writes.
int queueEndOf(List<TimelineEvent> tasks, PlanItems items) =>
    _placeIn(tasks, items, '', null);

/// Begins [artifact], asking its day first when it has none.
Future<void> _begin(BuildContext context, Artifact artifact) async {
  final cubit = context.read<ArtifactsCubit>();
  if (artifact.deadline != null) return cubit.start(artifact.id);
  final deadline = await showStartSheet(context, artifact);
  if (deadline == null) return;
  return cubit.start(artifact.id, deadline: deadline);
}

/// {@template plan_draggable}
/// A card of Plano that can be held and carried to another section, or to
/// another place in Em seguida. Its own place closes while it is carried
/// (the others close up, as in a list being reordered); under the finger
/// goes a plain card with its name, and where it would land, a quiet copy
/// of it ([PlanDropGhost]).
/// {@endtemplate}
class PlanDraggable extends StatelessWidget {
  /// {@macro plan_draggable}
  const PlanDraggable({
    required this.carry,
    required this.child,
    this.onCarry,
    super.key,
  });

  /// What it carries.
  final PlanCarry carry;

  /// Told true when it is picked up and false when it is let go.
  final ValueChanged<bool>? onCarry;

  /// The card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<PlanCarry>(
        data: carry,
        feedback: Material(
          color: Colors.transparent,
          elevation: 6,
          shadowColor: AppColors.shadow,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: SizedBox(
            width: constraints.maxWidth,
            child: TaskCard(title: carry.title),
          ),
        ),
        childWhenDragging: const SizedBox.shrink(),
        onDragStarted: () => onCarry?.call(true),
        onDragEnd: (_) => onCarry?.call(false),
        child: child,
      ),
    );
  }
}

/// {@template plan_drop_target}
/// A section of Plano as a place to let a card go. Agora draws itself as
/// the place that starts it (`NowDropZone`); Pendentes and Para depois
/// draw the card's quiet copy at their top ([PlanDropGhost]), where it
/// lands. A card is never taken back by its own section.
/// {@endtemplate}
class PlanDropTarget extends StatelessWidget {
  /// {@macro plan_drop_target}
  const PlanDropTarget({
    required this.section,
    required this.onDrop,
    required this.builder,
    super.key,
  });

  /// Which section this is.
  final PlanSection section;

  /// What letting a card go here does.
  final void Function(PlanCarry carry) onDrop;

  /// The section, drawn with the card carried over it, or none.
  final Widget Function(BuildContext context, {PlanCarry? hovering}) builder;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlanCarry>(
      onWillAcceptWithDetails: (details) => details.data.from != section,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) =>
          builder(context, hovering: candidates.firstOrNull),
    );
  }
}

/// {@template plan_queue}
/// Em seguida as a queue: [cards] one under another, each a place to let a
/// card go **before** it, and the room under the last one a place after
/// it. Where the carried card would land, its quiet copy opens
/// ([PlanDropGhost]) and the cards under it make room.
/// {@endtemplate}
class PlanQueue extends StatelessWidget {
  /// {@macro plan_queue}
  const PlanQueue({
    required this.cards,
    required this.itemBuilder,
    required this.onDrop,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The queue, in order.
  final List<TimelineEvent> cards;

  /// Draws one card (carriable or not).
  final Widget Function(BuildContext context, TimelineEvent card) itemBuilder;

  /// Letting a card go before a card of the queue, or at its end (null).
  final void Function(PlanCarry carry, TimelineEvent? before) onDrop;

  /// Around each card and copy.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    Widget slot(TimelineEvent? before, Widget? child) {
      return DragTarget<PlanCarry>(
        onWillAcceptWithDetails: (details) => details.data.id != before?.id,
        onAcceptWithDetails: (details) => onDrop(details.data, before),
        builder: (context, candidates, _) {
          final carried = candidates.firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (carried != null)
                Padding(
                  padding: padding,
                  child: PlanDropGhost(carry: carried),
                ),
              if (child != null)
                Padding(padding: padding, child: child)
              else
                // The room under the last card, so the end of the queue is
                // somewhere to aim.
                const SizedBox(height: AppSpacing.s3),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards)
          KeyedSubtree(
            key: ValueKey(card.id),
            child: slot(card, itemBuilder(context, card)),
          ),
        slot(null, null),
      ],
    );
  }
}

/// {@template plan_drop_ghost}
/// Where a carried card would land: the card itself, its name and length,
/// drawn quiet (a third of its ink, no fill of its own), with no words of
/// instruction. It is the only thing a drop target draws.
/// {@endtemplate}
class PlanDropGhost extends StatelessWidget {
  /// {@macro plan_drop_ghost}
  const PlanDropGhost({required this.carry, super.key});

  /// What is carried.
  final PlanCarry carry;

  @override
  Widget build(BuildContext context) {
    final minutes = switch (carry) {
      CarryCard(:final card) => card.workMinutes,
      CarryDelivery(:final artifact) => artifact.minutes,
    };
    return IgnorePointer(
      child: Opacity(
        opacity: 0.4,
        child: TaskCard(
          title: carry.title,
          trailing: durationLabel(context.l10n, minutes),
          keepPlaySlot: true,
        ),
      ),
    );
  }
}

/// Unawaited [dropOnPlan], for a target's callback.
void Function(PlanCarry) planDropper(
  BuildContext context,
  PlanSection to,
  PlanItems items,
) =>
    (carry) => unawaited(dropOnPlan(context, carry, to, items));

/// Unawaited [dropOnPlan] on Em seguida, before a card or at its end.
void Function(PlanCarry, TimelineEvent?) queueDropper(
  BuildContext context,
  PlanItems items,
) =>
    (carry, before) => unawaited(
      dropOnPlan(context, carry, PlanSection.next, items, before: before),
    );
