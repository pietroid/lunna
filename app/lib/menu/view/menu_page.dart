import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template menu_page}
/// Everything that is not the day itself: the routines, and when the day
/// starts and ends.
///
/// The working day is read off the [TimelineBloc], which has it from the
/// last day the server drew. A change is written to the server and the day
/// is asked for again, so the queue is laid out in the new hours at once.
/// {@endtemplate}
class MenuPage extends StatefulWidget {
  /// {@macro menu_page}
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool _busy = false;

  /// Why the last change did not happen, as it should be read.
  String? _failure;

  Future<void> _pick({required bool start}) async {
    final bloc = context.read<TimelineBloc>();
    final repository = context.read<TimelineRepository>();
    final l10n = context.l10n;
    final current = bloc.state.workDay;

    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final picked = await AppWheelPicker.time(
      context,
      initial: midnight.add(
        Duration(minutes: (start ? current.start : current.end) % (24 * 60)),
      ),
      earliest: midnight,
    );
    if (picked == null || !mounted) return;

    var minutes = picked.hour * 60 + picked.minute;
    // Midnight as an end is the one that closes the day, not the one that
    // opens it.
    if (!start && minutes == 0) minutes = 24 * 60;

    final next = start
        ? current.copyWith(start: minutes)
        : current.copyWith(end: minutes);
    if (next == current) return;
    if (next.end - next.start < WorkDay.minimum.inMinutes) {
      setState(() => _failure = l10n.menuDayTooShort);
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await repository.setWorkDay(next);
      bloc.add(const TimelineRequested());
    } on TimelineFailure catch (failure) {
      if (mounted) {
        setState(
          () => _failure = failure.message ?? l10n.failureUnreachable,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workDay = context.select<TimelineBloc, WorkDay>(
      (bloc) => bloc.state.workDay,
    );
    final failure = _failure;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s5,
              AppSpacing.s6,
              // Room under the last row so the bar never covers it.
              AppSpacing.s16 + AppSpacing.s12,
            ),
            children: [
              Text(l10n.shellMenuTab, style: AppTypography.headline),
              const SizedBox(height: AppSpacing.s5),
              AppListItem(
                title: l10n.homeRoutines,
                subtitle: l10n.menuRoutinesHint,
                iconData: AppIcons.repeat,
                onTap: () => unawaited(context.push<void>('/rotina')),
              ),
              AppListItem(
                title: l10n.menuArchive,
                subtitle: l10n.menuArchiveHint,
                iconData: AppIcons.archive,
                onTap: () => unawaited(context.push<void>('/feitas')),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                l10n.menuDaySection,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppListItem(
                title: l10n.menuDayStart,
                subtitle: WorkDay.formatMinutes(workDay.start),
                iconData: AppIcons.time,
                onTap: _busy ? null : () => unawaited(_pick(start: true)),
              ),
              AppListItem(
                title: l10n.menuDayEnd,
                subtitle: WorkDay.formatMinutes(workDay.end),
                iconData: AppIcons.time,
                onTap: _busy ? null : () => unawaited(_pick(start: false)),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                failure ?? l10n.menuDayHelp,
                style: AppTypography.body.copyWith(
                  color: failure == null ? AppColors.ink3 : AppColors.dangerInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
