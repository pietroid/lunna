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
/// The weekend's two days, each a working day, a light one or a day off;
/// how much a light day takes; and the dates off ahead, the ones written
/// down here and the periods the cycle makes light or off, so the person
/// sees every day that is not a working day whatever set it.
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
                    const SizedBox(height: AppSpacing.s6),
                    Text(l10n.daysOffDates, style: hint),
                    const SizedBox(height: AppSpacing.s2),
                    ..._dates(context, rhythm),
                    AppAddRow(onTap: onAdd ?? () {}),
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

  /// The dates off ahead and the cycle's next period, in the order of their
  /// days.
  List<Widget> _dates(BuildContext context, Rhythm rhythm) {
    final l10n = context.l10n;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycle = rhythm.cycle;

    final rows = <(DateTime, Widget)>[
      for (final day in rhythm.daysOff)
        (
          day.day,
          AppListItem(
            title: l10n.daysOffEntry(day.day, day.title),
            iconData: AppIcons.dayOff,
            onTap: () {},
          ),
        ),
    ];

    if (cycle != null && cycle.periodKind != DayKind.work) {
      // The next period that has not begun yet.
      var start = cycle.lastStart;
      while (!start.isAfter(today)) {
        start = DateTime(start.year, start.month, start.day + cycle.length);
      }
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
              iconData: AppIcons.repeat,
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
