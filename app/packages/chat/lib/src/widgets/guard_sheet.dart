import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/timeline_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/a2ui_renderer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template guard_sheet}
/// The question a drag raised, drawn over the timeline.
///
/// It is an A2UI tree, rendered by the same renderer a reply is rendered by,
/// because it is the same kind of thing: the server saying something and
/// offering the ways to answer it. Nothing in here knows what a duration is,
/// what the working day is, or what happens to the afternoon when a block is
/// pushed into it. It draws buttons and posts the one that was tapped.
///
/// While it is open the timeline behind it is the one from before the drag.
/// Dismissing it therefore costs nothing: there is no move to undo, because
/// the move never happened.
/// {@endtemplate}
class GuardSheet extends StatelessWidget {
  /// {@macro guard_sheet}
  const GuardSheet({required this.guard, required this.busy, super.key});

  /// The tree the server sent.
  final A2uiComponent guard;

  /// Whether the last answer is still in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tapping the dimmed timeline is the same as cancelling, which is
        // what a sheet over a screen already means everywhere else.
        Positioned.fill(
          child: GestureDetector(
            onTap: () =>
                context.read<TimelineBloc>().add(const GuardDismissed()),
            child: ColoredBox(color: AppColors.bg.withValues(alpha: 0.72)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Panel(guard: guard, busy: busy),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.guard, required this.busy});

  final A2uiComponent guard;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s5,
              AppSpacing.s6,
              AppSpacing.s5,
            ),
            child: Opacity(
              // The panel goes quiet while the server works out what the
              // answer did, rather than closing and reopening: the next
              // question, when there is one, belongs in the same sheet.
              opacity: busy ? 0.5 : 1,
              child: A2uiRenderer(
                component: guard,
                enabled: !busy,
                onAction: (action) => _onAction(context, action),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onAction(BuildContext context, Map<String, dynamic> action) {
    final bloc = context.read<TimelineBloc>();

    // `dismiss` is the one action the app has always handled itself, and a
    // guard's Cancel is exactly that: close it, change nothing.
    if (action['type'] == 'dismiss') {
      bloc.add(const GuardDismissed());
      return;
    }

    // The sync popup's retry. It goes to its own route because it is not
    // about where a card sits: the day is already right, and this is the
    // copy of it on Google being pushed again.
    if (action['type'] == 'sync') {
      bloc.add(const SyncRetried());
      return;
    }

    bloc.add(GuardAnswered(action));
  }
}
