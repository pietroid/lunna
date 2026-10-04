import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/format.dart';

/// {@template guard_sheet}
/// The one question a drag can raise, drawn over the timeline.
///
/// Something is running and a card was just dropped at the top of the day.
/// Both answers start the dropped card now; they differ in what becomes of
/// the running one. The server decides what that does to the rest of the
/// day — this only asks.
///
/// While it is open the timeline behind it is the one from before the drag.
/// Dismissing it therefore costs nothing: there is no move to undo, because
/// the move never happened.
/// {@endtemplate}
class GuardSheet extends StatelessWidget {
  /// {@macro guard_sheet}
  const GuardSheet({required this.guard, required this.busy, super.key});

  /// The question the server asked.
  final StartNowGuard guard;

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

  final StartNowGuard guard;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<TimelineBloc>();

    void answer(TimingDecision decision) {
      if (!busy) bloc.add(GuardAnswered(decision));
    }

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
              // answer did, rather than closing and reopening.
              opacity: busy ? 0.5 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppListItem(
                    iconData: AppIcons.timer,
                    title: l10n.guardStartNowTitle,
                    subtitle: l10n.guardStartNowRunning(
                      guard.currentTitle,
                      hhmm(guard.currentStart),
                      hhmm(guard.currentEnd),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppButton.icon(
                    icon: const AppIcon(
                      iconData: AppIcons.check,
                      color: AppColors.onAccent,
                    ),
                    text: l10n.guardFinishCurrent,
                    expand: true,
                    onPressed: () => answer(TimingDecision.solveCurrent),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  AppButton(
                    text: l10n.guardPostponeCurrent,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: () => answer(TimingDecision.postponeCurrent),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  AppButton.text(
                    text: l10n.commonCancel,
                    color: AppColors.ink2,
                    expand: true,
                    onPressed: () => bloc.add(const GuardDismissed()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
