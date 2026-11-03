import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
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
/// - **Em seguida** puts the task (or a delivery's next task) right after
///   what runs.
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
  PlanItems items,
) async {
  if (carry.from == to) return;
  final bloc = context.read<TimelineBloc>();
  final deliveries = context.read<ArtifactsCubit>();

  switch ((carry, to)) {
    case (CarryCard(:final card), PlanSection.now):
      bloc.add(EventMoved(id: card.id, index: 0, start: true));
    case (CarryDelivery(:final artifact), PlanSection.now):
      await playPending(context, artifact);

    case (CarryCard(:final card), PlanSection.next):
      bloc.add(EventMoved(id: card.id, index: _nextIndex(items, card.id)));
    case (CarryDelivery(:final artifact), PlanSection.next):
      final task = nextTaskOf(artifact);
      if (task == null) return;
      bloc.add(EventMoved(id: task.id, index: _nextIndex(items, task.id)));

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

/// The place in the list of tasks right under what runs on Agora, counted
/// with [id] taken out, as a move counts.
int _nextIndex(PlanItems items, String id) {
  final now = items.now;
  return now != null && now.isTask && now.id != id ? 1 : 0;
}

/// Begins [artifact], asking its day first when it has none.
Future<void> _begin(BuildContext context, Artifact artifact) async {
  final cubit = context.read<ArtifactsCubit>();
  if (artifact.deadline != null) return cubit.start(artifact.id);
  final deadline = await showStartSheet(context, artifact);
  if (deadline == null) return;
  return cubit.start(artifact.id, deadline: deadline);
}

/// {@template plan_draggable}
/// A card of Plano that can be held and carried to another section. It
/// leaves a gap where it was while it is carried; under the finger goes a
/// plain card with its name.
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
        childWhenDragging: Visibility.maintain(visible: false, child: child),
        onDragStarted: () => onCarry?.call(true),
        onDragEnd: (_) => onCarry?.call(false),
        child: child,
      ),
    );
  }
}

/// {@template plan_drop_target}
/// A section of Plano as a place to let a card go. Agora draws itself as
/// the place that starts it (`NowDropZone`); the others open a gap at their
/// top ([PlanDropGap]). A card is never taken back by its own section.
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

  /// The section, drawn hovering (a card over it) or not.
  final Widget Function(BuildContext context, {required bool hovering}) builder;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlanCarry>(
      onWillAcceptWithDetails: (details) => details.data.from != section,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) =>
          builder(context, hovering: candidates.isNotEmpty),
    );
  }
}

/// The gap a section opens at its top while a card is carried over it.
class PlanDropGap extends StatelessWidget {
  /// A gap.
  const PlanDropGap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Text(
        context.l10n.planDropHere,
        style: AppTypography.labelStrong.copyWith(color: AppColors.accent),
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
