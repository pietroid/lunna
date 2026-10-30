import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:cycle/src/cycle_cubit.dart';
import 'package:cycle/src/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template cycle_page}
/// The cycle (`/ciclo`, from the Menu): where it stands today and what that
/// does to the day, the next 30 days by phase, and what the phases are
/// worked out from.
///
/// The one thing to do here most months is to say the period began, so
/// that is the page's button; the lengths and what a day of the period is
/// are set once and left.
/// {@endtemplate}
class CyclePage extends StatelessWidget {
  /// {@macro cycle_page}
  const CyclePage({this.dock, super.key});

  /// The agent's bar, floated over the page as on every screen.
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(l10n.cycleTitle, style: AppTypography.title),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: BlocBuilder<CycleCubit, CycleState>(
              builder: (context, state) {
                final cubit = context.read<CycleCubit>();
                final rhythm = state.data;
                final cycle = rhythm?.cycle;
                final today = _dayOf(clock.now());

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    AppSpacing.s2,
                    AppSpacing.s6,
                    kNotesDockClearance,
                  ),
                  children: [
                    if (cycle != null) ...[
                      _Today(
                        cycle: cycle,
                        today: today,
                        lightMinutes: rhythm!.rules.lightMinutes,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                    ],
                    AppButton(
                      expand: true,
                      text: l10n.cycleStarted,
                      onPressed: state.status == CycleStatus.loading
                          ? null
                          : () => unawaited(cubit.periodStarted(today)),
                    ),
                    if (cycle != null) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Text(l10n.cycleNext30, style: AppTypography.title),
                      const SizedBox(height: AppSpacing.s3),
                      _Next30(cycle: cycle, today: today),
                      const SizedBox(height: AppSpacing.s3),
                      const _Legend(),
                    ],
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      l10n.cycleSettings,
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    AppListItem(
                      title: l10n.cycleLastStart,
                      subtitle: cycle == null
                          ? null
                          : l10n.cycleDate(cycle.lastStart),
                      iconData: AppIcons.calendar,
                      onTap: () {},
                    ),
                    AppListItem(
                      title: l10n.cycleLength,
                      subtitle: l10n.cycleDays(cycle?.length ?? 28),
                      iconData: AppIcons.repeat,
                      onTap: () {},
                    ),
                    AppListItem(
                      title: l10n.cyclePeriodLength,
                      subtitle: l10n.cycleDays(cycle?.periodLength ?? 5),
                      iconData: AppIcons.cycleMenstrual,
                      onTap: () {},
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(l10n.cyclePeriodKind, style: AppTypography.label),
                    const SizedBox(height: AppSpacing.s2),
                    DayKindChoice(
                      kind: cycle?.periodKind ?? DayKind.light,
                      onChanged: cycle == null
                          ? null
                          : (kind) => unawaited(
                              cubit.saveCycle(cycle.copyWith(periodKind: kind)),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      l10n.cycleHelp,
                      style: AppTypography.body.copyWith(color: AppColors.ink3),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: dock,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
    );
  }

  static DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);
}

/// Normal, Leve or Folga: what a kind of day is to the queue.
class DayKindChoice extends StatelessWidget {
  /// Draws [kind] chosen; [onChanged] null, it cannot be changed.
  const DayKindChoice({required this.kind, this.onChanged, super.key});

  /// The kind chosen.
  final DayKind kind;

  /// Chooses another.
  final ValueChanged<DayKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onChanged = this.onChanged;

    return AppSegmented(
      segments: [
        AppSegment(label: l10n.dayKindWork, iconData: AppIcons.time),
        AppSegment(label: l10n.dayKindLight, iconData: AppIcons.dayLight),
        AppSegment(label: l10n.dayKindOff, iconData: AppIcons.dayOff),
      ],
      selected: kind.index,
      onSelected: (index) => onChanged?.call(DayKind.values[index]),
    );
  }
}

/// Where the cycle stands today: the phase's mark, the day of the cycle,
/// until when the phase lasts, and what it does to the day.
class _Today extends StatelessWidget {
  const _Today({
    required this.cycle,
    required this.today,
    required this.lightMinutes,
  });

  final Cycle cycle;
  final DateTime today;
  final int lightMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phase = cycle.phaseOn(today)!;
    final kind = phase == CyclePhase.menstrual
        ? cycle.periodKind
        : DayKind.work;
    final effect = switch (kind) {
      DayKind.light => l10n.cycleEffectLight(
        durationLabel(l10n, lightMinutes),
      ),
      DayKind.off => l10n.cycleEffectOff,
      DayKind.work => l10n.cycleEffectWork,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: phase.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.s12,
            height: AppSpacing.s12,
            decoration: const BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(
              iconData: phase.icon,
              size: 26,
              color: phase.ink,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cycleTodayOf(cycle.dayOn(today)!, cycle.length),
                  style: AppTypography.headline,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  l10n.cyclePhaseUntil(
                    phase.label(l10n),
                    cycle.phaseEnd(today)!,
                  ),
                  style: AppTypography.labelStrong.copyWith(color: phase.ink),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  effect,
                  style: AppTypography.body.copyWith(color: AppColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The next 30 days, a week to a row, each day in its phase's colours and
/// today ringed.
class _Next30 extends StatelessWidget {
  const _Next30({required this.cycle, required this.today});

  final Cycle cycle;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final initials = context.l10n.cycleWeekdays.split(',');
    // Sunday first, as a Brazilian calendar is.
    final lead = today.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var i = 0; i < 30; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    Widget row(List<Widget> children) => Row(
      children: [
        for (final child in children) Expanded(child: Center(child: child)),
      ],
    );

    return Column(
      children: [
        row([
          for (final initial in initials)
            Text(initial, style: AppTypography.caption),
        ]),
        const SizedBox(height: AppSpacing.s2),
        for (var week = 0; week < cells.length ~/ 7; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s1),
            child: row([
              for (final day in cells.skip(week * 7).take(7))
                day == null
                    ? const SizedBox(height: 40)
                    : _DayCell(
                        day: day,
                        phase: cycle.phaseOn(day),
                        today: day == today,
                      ),
            ]),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.phase, required this.today});

  final DateTime day;
  final CyclePhase? phase;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final phase = this.phase;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: phase?.fill ?? AppColors.fill,
        shape: BoxShape.circle,
        border: today ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      child: Text(
        '${day.day}',
        style: AppTypography.labelStrong.copyWith(
          color: phase?.ink ?? AppColors.ink2,
        ),
      ),
    );
  }
}

/// The four phases, each with its mark, under the grid.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final phase in CyclePhase.values)
          AppTag(
            text: phase.label(l10n),
            iconData: phase.icon,
            fill: phase.fill,
            ink: phase.ink,
          ),
      ],
    );
  }
}
