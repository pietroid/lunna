import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/things_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template things_list}
/// Coisas: the timeline with the clock taken out.
///
/// The same gestures as the day and none of its hours. A press held for a
/// moment picks a thing up and puts it somewhere else in the order; carried
/// out to the right it is done, out to the left it is deleted once the user
/// has said so. No times, no headings, no "ontem": the list is an order and
/// nothing else.
///
/// Each row has one button, which moves the thing onto the timeline, into
/// the first gap that fits it. That is the only way a thing gets an hour.
/// {@endtemplate}
class ThingsList extends StatelessWidget {
  /// {@macro things_list}
  const ThingsList({required this.onThingTap, super.key});

  /// Opens a thing to rename it or change how long it takes.
  final ValueChanged<Thing> onThingTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThingsBloc, ThingsState>(
      builder: (context, state) {
        if (state.isInitialLoad) return const _Loading();

        final failure = state.failure;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null)
              _Failed(
                reason: failure,
                onRetry: () =>
                    context.read<ThingsBloc>().add(const ThingsRequested()),
              ),
            Expanded(
              child: state.things.isEmpty
                  ? const _Empty()
                  : _Reorderable(things: state.things, onTap: onThingTap),
            ),
          ],
        );
      },
    );
  }
}

class _Reorderable extends StatelessWidget {
  const _Reorderable({required this.things, required this.onTap});

  final List<Thing> things;
  final ValueChanged<Thing> onTap;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ThingsBloc>();

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(
        top: AppSpacing.s2,
        // Room under the last row so the bar never covers it.
        bottom: AppSpacing.s16 + AppSpacing.s12,
      ),
      itemCount: things.length,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.bg,
        child: child,
      ),
      onReorderStart: (_) => unawaited(HapticFeedback.selectionClick()),
      // The index comes counted with the row lifted out, which is how the
      // server counts it too.
      onReorderItem: (from, index) {
        if (index == from) return;

        bloc.add(ThingMoved(id: things[from].id, index: index));
      },
      itemBuilder: (context, index) {
        final thing = things[index];

        return ReorderableDelayedDragStartListener(
          key: ValueKey(thing.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s1),
            child: _Swipe(
              thing: thing,
              child: _Row(
                thing: thing,
                onTap: () => onTap(thing),
                onSchedule: () => bloc.add(ThingScheduled(thing.id)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Out to the right is done, out to the left is a delete that asks first.
class _Swipe extends StatelessWidget {
  const _Swipe({required this.thing, required this.child});

  final Thing thing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ThingsBloc>();

    return Dismissible(
      key: ValueKey('swipe-${thing.id}'),
      background: const _Mark(
        icon: AppIcons.check,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _Mark(
        icon: AppIcons.trash,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        unawaited(HapticFeedback.mediumImpact());
        if (direction == DismissDirection.startToEnd) return true;

        return confirmDelete(
          context,
          thing.title,
          body: 'Sai da lista e não volta.',
        );
      },
      onDismissed: (direction) => bloc.add(
        direction == DismissDirection.startToEnd
            ? ThingFinished(thing.id)
            : ThingDeleted(thing.id),
      ),
      child: child,
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.alignment});

  final AppIconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: AppIcon(iconData: icon, color: AppColors.ink2),
      ),
    );
  }
}

/// One thing: what it is, how long it takes, and the way onto the day.
class _Row extends StatelessWidget {
  const _Row({
    required this.thing,
    required this.onTap,
    required this.onSchedule,
  });

  final Thing thing;
  final VoidCallback onTap;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.s4,
            top: AppSpacing.s1,
            bottom: AppSpacing.s1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  thing.title,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                formatDuration(Duration(minutes: thing.durationMinutes)),
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
              AppIconButton(
                iconData: AppIcons.prioritize,
                color: AppColors.ink2,
                onPressed: onSchedule,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s2),
        child: Text(
          '$reason Toque para tentar de novo.',
          style: AppTypography.label.copyWith(color: AppColors.ink3),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Text(
        'Nada por aqui. Toque no orbe para anotar uma coisa.',
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: AppSpacing.s2),
        AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
        SizedBox(height: AppSpacing.s1),
        AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
      ],
    );
  }
}
