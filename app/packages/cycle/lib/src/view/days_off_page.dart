import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:cycle/src/cycle_cubit.dart';
import 'package:cycle/src/models.dart';
import 'package:cycle/src/view/cycle_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template days_off_page}
/// Folgas (`/folgas`, from the Menu): every day the queue keeps off or goes
/// easy on, in one place.
///
/// The weekend's two days, each a working day, a light one or a day off
/// (off until the person says otherwise); the next 30 days' folgas,
/// whatever set them: each weekend, which **Trabalhar** puts back to work
/// for that weekend alone (and Desfazer gives back), the dates written
/// down here, and the period the cycle makes light or off; and how much a
/// light day takes.
/// {@endtemplate}
class DaysOffPage extends StatelessWidget {
  /// {@macro days_off_page}
  const DaysOffPage({this.onAdd, this.dock, super.key});

  /// The agent's bar, floated over the page as on every screen.
  final Widget? dock;

  /// Writes a new date off.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = AppTypography.label.copyWith(color: AppColors.ink3);

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(l10n.daysOffTitle, style: AppTypography.title),
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
                final rhythm = state.data ?? const Rhythm();
                final rules = rhythm.rules;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    AppSpacing.s2,
                    AppSpacing.s6,
                    kNotesDockClearance,
                  ),
                  children: [
                    Text(l10n.daysOffWeekend, style: hint),
                    const SizedBox(height: AppSpacing.s3),
                    Text(l10n.daysOffSaturday, style: AppTypography.label),
                    const SizedBox(height: AppSpacing.s2),
                    DayKindChoice(
                      kind: rules.saturday,
                      onChanged: (kind) => unawaited(
                        cubit.saveRules(rules.copyWith(saturday: kind)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(l10n.daysOffSunday, style: AppTypography.label),
                    const SizedBox(height: AppSpacing.s2),
                    DayKindChoice(
                      kind: rules.sunday,
                      onChanged: (kind) => unawaited(
                        cubit.saveRules(rules.copyWith(sunday: kind)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      l10n.daysOffWeekendHelp,
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(l10n.daysOffDates, style: hint),
                    const SizedBox(height: AppSpacing.s2),
                    ..._dates(context, rhythm),
                    AppAddRow(onTap: onAdd ?? () {}),
                    const SizedBox(height: AppSpacing.s6),
                    Text(l10n.daysOffLight, style: hint),
                    const SizedBox(height: AppSpacing.s2),
                    AppListItem(
                      title: l10n.daysOffLightBudget,
                      subtitle: durationLabel(l10n, rules.lightMinutes),
                      iconData: AppIcons.dayLight,
                      onTap: () {},
                    ),
                    Text(
                      l10n.daysOffLightHelp,
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

  /// The next 30 days' folgas in the order of their days: each weekend,
  /// the dates off and the cycle's next period.
  List<Widget> _dates(BuildContext context, Rhythm rhythm) {
    final l10n = context.l10n;
    final cubit = context.read<CycleCubit>();
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = DateTime(today.year, today.month, today.day + 30);
    final cycle = rhythm.cycle;
    final rules = rhythm.rules;

    DayOff? written(DateTime day) {
      for (final date in rhythm.daysOff) {
        if (date.day == day) return date;
      }
      return null;
    }

    final rows = <(DateTime, Widget)>[
      for (final day in rhythm.daysOff)
        if (day.kind == DayKind.off)
          (
            day.day,
            AppListItem(
              title: l10n.daysOffEntry(day.day, day.title),
              iconData: AppIcons.dayOff,
              onTap: () {},
            ),
          ),
    ];

    if (rules.saturday != DayKind.work || rules.sunday != DayKind.work) {
      var saturday = DateTime(
        today.year,
        today.month,
        today.day + (DateTime.saturday - today.weekday) % 7,
      );
      while (saturday.isBefore(until)) {
        final sunday = DateTime(
          saturday.year,
          saturday.month,
          saturday.day + 1,
        );
        // Put back to work, for this weekend alone.
        final worked = [
          for (final day in [saturday, sunday])
            if (written(day) case final date? when date.kind == DayKind.work)
              date,
        ];
        final working = worked.isNotEmpty;
        rows.add((
          saturday,
          _Weekend(
            dates: l10n.daysOffWeekendEntry(saturday, sunday),
            working: working,
            onPressed: working
                ? () => unawaited(
                    cubit.remove([for (final date in worked) date.id]),
                  )
                : () => unawaited(cubit.workOn([saturday, sunday])),
          ),
        ));
        saturday = DateTime(saturday.year, saturday.month, saturday.day + 7);
      }
    }

    if (cycle != null && cycle.periodKind != DayKind.work) {
      final start = cycle.predictedStart;
      final end = DateTime(
        start.year,
        start.month,
        start.day + cycle.periodLength - 1,
      );
      rows.add((
        start,
        Row(
          children: [
            Expanded(
              child: AppListItem(
                title: l10n.daysOffRange(
                  start,
                  end,
                  l10n.cyclePhaseMenstrual,
                ),
                iconData: AppIcons.cycleMenstrual,
                color: AppColors.cycleMenstrual,
              ),
            ),
            AppTag(
              text: cycle.periodKind == DayKind.off
                  ? l10n.dayKindOff
                  : l10n.dayKindLight,
              iconData: AppIcons.cycleMenstrual,
              fill: AppColors.cycleMenstrualFill,
              ink: AppColors.cycleMenstrual,
            ),
          ],
        ),
      ));
    }

    rows.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final row in rows) row.$2];
  }
}

/// A weekend in the list: off, with **Trabalhar**, or put back to work,
/// with **Desfazer**.
class _Weekend extends StatelessWidget {
  const _Weekend({
    required this.dates,
    required this.working,
    required this.onPressed,
  });

  final String dates;
  final bool working;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: AppListItem(
            title: l10n.daysOffWeekend,
            subtitle: working ? l10n.daysOffWorking(dates) : dates,
            iconData: working ? AppIcons.time : AppIcons.dayOff,
            color: working ? AppColors.ink3 : AppColors.ink2,
          ),
        ),
        AppButton.text(
          text: working ? l10n.daysOffUndo : l10n.daysOffWork,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
