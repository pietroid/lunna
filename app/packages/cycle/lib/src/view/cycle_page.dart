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
/// that is the page's button. **Every prediction is the person's to
/// change**: a tap on any day of the grid opens [CycleDaySheet], which
/// says the period began there (a day gone) or will begin there (a day
/// ahead); the lengths and what a day of the period is are set once and
/// left.
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.cycleNext30,
                              style: AppTypography.title,
                            ),
                          ),
                          Text(
                            l10n.cycleTapHint,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      _Next30(
                        cycle: cycle,
                        today: today,
                        onTap: (day) =>
                            unawaited(showCycleDaySheet(context, day)),
                      ),
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
                      onTap: () => unawaited(_pickStart(context, today)),
                    ),
                    if (cycle != null)
                      AppListItem(
                        title: l10n.cycleNextStart,
                        subtitle: cycle.nextStart == null
                            ? l10n.cycleNextPredicted(cycle.predictedStart)
                            : l10n.cycleNextCorrected(cycle.predictedStart),
                        iconData: AppIcons.pen,
                        onTap: () => unawaited(
                          showCycleDaySheet(context, cycle.predictedStart),
                        ),
                      ),
                    AppListItem(
                      title: l10n.cycleLength,
                      subtitle: l10n.cycleDays(cycle?.length ?? 28),
                      iconData: AppIcons.repeat,
                      onTap: cycle == null
                          ? null
                          : () => unawaited(
                              _pickCount(
                                context,
                                title: l10n.cyclePickLength,
                                initial: cycle.length,
                                min: 21,
                                max: 45,
                                save: (value) => cycle.copyWith(length: value),
                              ),
                            ),
                    ),
                    AppListItem(
                      title: l10n.cyclePeriodLength,
                      subtitle: l10n.cycleDays(cycle?.periodLength ?? 5),
                      iconData: AppIcons.cycleMenstrual,
                      onTap: cycle == null
                          ? null
                          : () => unawaited(
                              _pickCount(
                                context,
                                title: l10n.cyclePickPeriod,
                                initial: cycle.periodLength,
                                min: 1,
                                max: 10,
                                save: (value) =>
                                    cycle.copyWith(periodLength: value),
                              ),
                            ),
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
                      state.status == CycleStatus.failure
                          ? l10n.daysOffFailure
                          : l10n.cycleHelp,
                      style: AppTypography.body.copyWith(
                        color: state.status == CycleStatus.failure
                            ? AppColors.dangerInk
                            : AppColors.ink3,
                      ),
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

  /// The last period's first day, from the date wheel: a day gone, within
  /// the last 90. Without a cycle it is the first one written down.
  static Future<void> _pickStart(BuildContext context, DateTime today) async {
    final cubit = context.read<CycleCubit>();
    final cycle = cubit.state.data?.cycle;
    final picked = await AppWheelPicker.date(
      context,
      initial: cycle?.lastStart ?? today,
      first: DateTime(today.year, today.month, today.day - 90),
      last: today,
    );
    if (picked == null || picked == cycle?.lastStart) return;
    await (cycle == null
        ? cubit.periodStarted(picked)
        : cubit.saveCycle(cycle.copyWith(lastStart: picked)));
  }

  /// A length, from a wheel of days, written down as [save] makes it.
  static Future<void> _pickCount(
    BuildContext context, {
    required String title,
    required int initial,
    required int min,
    required int max,
    required Cycle Function(int value) save,
  }) async {
    final cubit = context.read<CycleCubit>();
    final l10n = context.l10n;
    final picked = await AppWheelPicker.count(
      context,
      title: title,
      initial: initial,
      min: min,
      max: max,
      label: l10n.cycleDays,
    );
    if (picked == null || picked == initial) return;
    await cubit.saveCycle(save(picked));
  }
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
  const _Next30({required this.cycle, required this.today, this.onTap});

  final Cycle cycle;
  final DateTime today;
  final ValueChanged<DateTime>? onTap;

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
                        onTap: onTap == null ? null : () => onTap!(day),
                      ),
            ]),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.phase,
    required this.today,
    this.onTap,
  });

  final DateTime day;
  final CyclePhase? phase;
  final bool today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final phase = this.phase;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _cell(phase),
    );
  }

  Widget _cell(CyclePhase? phase) {
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

/// Opens [CycleDaySheet] on [day], handed the cubit it writes with.
Future<void> showCycleDaySheet(BuildContext context, DateTime day) {
  final cubit = context.read<CycleCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: CycleDaySheet(day: day),
    ),
  );
}

/// {@template cycle_day_sheet}
/// One day of the grid, to correct the prediction on: what the prediction
/// says of it, and one button. On today or a day gone, the period **began**
/// there (a new start, `POST /rhythm/cycle/start`); on a day ahead, the
/// next period **will begin** there (the cycle's `nextStart`), and the
/// cycles after it count from that day. Once moved, the next period can go
/// back to the prediction.
/// {@endtemplate}
class CycleDaySheet extends StatelessWidget {
  /// {@macro cycle_day_sheet}
  const CycleDaySheet({required this.day, super.key});

  /// The day tapped, at midnight.
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CycleCubit>();
    final cycle = cubit.state.data?.cycle;
    final now = clock.now();
    final ahead = day.isAfter(DateTime(now.year, now.month, now.day));
    final phase = cycle?.phaseOn(day);
    final at = cycle?.dayOn(day);

    void done(Future<void> write) {
      unawaited(write);
      unawaited(Navigator.of(context).maybePop());
    }

    return Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s2,
            AppSpacing.s5,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cycleDayTitle(day),
                      style: AppTypography.title,
                    ),
                  ),
                  AppIconButton(
                    iconData: AppIcons.close,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              if (phase != null && at != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTag(
                    text: l10n.cycleDayPredicted(at, phase.label(l10n)),
                    iconData: phase.icon,
                    fill: phase.fill,
                    ink: phase.ink,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                expand: true,
                text: ahead ? l10n.cycleDayWillStart : l10n.cycleDayStarted,
                onPressed: () => done(
                  ahead ? cubit.predictStart(day) : cubit.periodStarted(day),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                l10n.cycleDayHelp,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
              if (cycle?.nextStart != null) ...[
                const SizedBox(height: AppSpacing.s2),
                AppButton(
                  variant: AppButtonVariant.tertiary,
                  expand: true,
                  text: l10n.cycleBackToPrediction,
                  onPressed: () => done(cubit.predictStart(null)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
