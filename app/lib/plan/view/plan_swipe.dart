import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template plan_swipe}
/// A card of Plano that a swipe ticks off or deletes: to the right it is
/// done, to the left it is gone. Each asks first, with its own question,
/// and a task asks differently from a delivery ([PlanSwipe.task],
/// [PlanSwipe.delivery]). A no puts the card back where it was.
/// {@endtemplate}
class PlanSwipe extends StatefulWidget {
  /// {@macro plan_swipe}
  ///
  /// A task: done is [EventFinished], delete [EventDeleted]. A delivery's
  /// task (in Em seguida) is that task, not its delivery.
  PlanSwipe.task({required TimelineEvent card, required Widget child, Key? key})
    : this._(
        key: key ?? ValueKey('swipe-${card.id}'),
        id: card.id,
        askDone: (context) => confirmDone(context, card.title),
        askDelete: (context) => confirmDelete(
          context,
          card.title,
          body: context.l10n.confirmDeleteTaskBody,
        ),
        done: (context) async =>
            context.read<TimelineBloc>().add(EventFinished(card.id)),
        delete: (context) async =>
            context.read<TimelineBloc>().add(EventDeleted(card.id)),
        stays: (_) => false,
        child: child,
      );

  /// A delivery: done delivers it, delete removes it with what waited in
  /// its backlog.
  PlanSwipe.delivery({
    required Artifact artifact,
    required Widget child,
    Key? key,
  }) : this._(
         key: key ?? ValueKey('swipe-${artifact.id}'),
         id: artifact.id,
         askDone: (context) {
           final l10n = context.l10n;
           return confirmDone(
             context,
             artifact.title,
             question: l10n.confirmDeliverTitle(artifact.title),
             body: l10n.confirmDeliverBody,
             action: l10n.confirmDeliverAction,
           );
         },
         askDelete: (context) => confirmDelete(
           context,
           artifact.title,
           body: context.l10n.artifactDeleteBody,
         ),
         done: (context) =>
             context.read<ArtifactsCubit>().setDone(artifact.id, done: true),
         delete: (context) =>
             context.read<ArtifactsCubit>().delete(artifact.id),
         // The cubit draws neither before the server answers: a refusal
         // leaves it in the queue, and the card comes back.
         stays: (context) => context.read<ArtifactsCubit>().state.queue.any(
           (a) => a.id == artifact.id,
         ),
         child: child,
       );

  const PlanSwipe._({
    required this.id,
    required this.askDone,
    required this.askDelete,
    required this.done,
    required this.delete,
    required this.stays,
    required this.child,
    super.key,
  });

  /// What it is the card of.
  final String id;

  /// The question before done, and before delete.
  final Future<bool> Function(BuildContext context) askDone;

  /// The question before delete.
  final Future<bool> Function(BuildContext context) askDelete;

  /// Ticks it off.
  final Future<void> Function(BuildContext context) done;

  /// Takes it off for good.
  final Future<void> Function(BuildContext context) delete;

  /// Whether it is still there once the write has answered (refused).
  final bool Function(BuildContext context) stays;

  /// The card.
  final Widget child;

  @override
  State<PlanSwipe> createState() => _PlanSwipeState();
}

class _PlanSwipeState extends State<PlanSwipe> {
  /// Swiped away and confirmed: drawn as nothing until the list drops it.
  bool _gone = false;

  Future<bool> _ask(DismissDirection direction) async {
    unawaited(HapticFeedback.mediumImpact());
    return direction == DismissDirection.startToEnd
        ? widget.askDone(context)
        : widget.askDelete(context);
  }

  Future<void> _write(DismissDirection direction) async {
    setState(() => _gone = true);
    await (direction == DismissDirection.startToEnd
        ? widget.done(context)
        : widget.delete(context));
    if (mounted && widget.stays(context)) setState(() => _gone = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return Dismissible(
      key: ValueKey('dismiss-${widget.id}'),
      background: const _Mark(
        icon: AppIcons.check,
        ink: AppColors.success,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _Mark(
        icon: AppIcons.trash,
        ink: AppColors.dangerInk,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: _ask,
      onDismissed: (direction) => unawaited(_write(direction)),
      child: widget.child,
    );
  }
}

/// What a swipe uncovers: the mark of what letting go does.
class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.ink, required this.alignment});

  final AppIconData icon;
  final Color ink;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: AppIcon(iconData: icon, color: ink),
      ),
    );
  }
}
