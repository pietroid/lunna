import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:artifacts/src/view/sheet_rows.dart';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that writes a goal down, or changes [goal].
///
/// The sheet is its own route, so it is handed the cubit it writes with.
Future<void> showGoalSheet(BuildContext context, {int? amount, Goal? goal}) {
  final cubit = context.read<ArtifactsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: GoalSheet(initialAmount: amount ?? goal?.target, goal: goal),
    ),
  );
}

/// The day a new goal begins counting at [now], after [goals]: the day
/// after the last one's day when that is still ahead, otherwise today.
/// Goals follow each other, so money is never counted twice.
DateTime goalStartAfter(List<Goal> goals, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final ends = goals.map((g) => g.end).where((end) => end.isAfter(today));
  if (ends.isEmpty) return today;
  return ends.reduce((a, b) => a.isAfter(b) ? a : b);
}

/// The two days a goal is offered, counted from [from]: the Sunday of the
/// week after its own, and the last day of the month after its own.
({DateTime week, DateTime month}) goalSuggestions(DateTime from) => (
  week: DateTime(from.year, from.month, from.day + 7 - from.weekday + 7),
  month: DateTime(from.year, from.month + 2, 0),
);

/// {@template goal_sheet}
/// A goal in two choices: how much to bill, and by when.
///
/// The day is offered rather than asked: the end of next week, or the end
/// of next month (picked when it opens), and any other day on the wheel.
/// A goal begins where the last one ends, or today, so the line at the foot
/// reads it back with the day it begins and what it asks per week.
///
/// Opened on a [goal], it changes that one: its amount and its day, on
/// the wheel, from the day it began.
/// {@endtemplate}
class GoalSheet extends StatefulWidget {
  /// {@macro goal_sheet}
  const GoalSheet({this.initialAmount, this.goal, super.key});

  /// How much it asks for when it opens.
  final int? initialAmount;

  /// The goal it changes; null writes a new one.
  final Goal? goal;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  /// Which day: next week, next month, or [_other].
  late int _by = widget.goal == null ? 1 : 2;
  late DateTime? _other = widget.goal?.lastDay;
  late final _amount = TextEditingController(
    text: widget.initialAmount?.toString(),
  );
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickOther(DateTime from, DateTime initial) async {
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: initial,
      // Its last day comes after its first.
      earliest: DateTime(from.year, from.month, from.day + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _by = 2;
      _other = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save(int target, DateTime by) async {
    final cubit = context.read<ArtifactsCubit>();
    final goal = widget.goal;
    setState(() => _busy = true);
    final made = goal == null
        ? await cubit.addGoal(target: target, deadline: by)
        : await cubit.editGoal(
            goal.id,
            target: target == goal.target ? null : target,
            deadline: by == goal.lastDay ? null : by,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (made) unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final goals = context.watch<ArtifactsCubit>().state.data?.goals ?? [];
    final editing = widget.goal;
    final from = editing?.start ?? goalStartAfter(goals, now);
    final offered = goalSuggestions(from);
    final by = switch (_by) {
      0 => offered.week,
      1 => offered.month,
      _ => _other ?? offered.month,
    };
    final target = int.tryParse(_amount.text.trim()) ?? 0;
    final weeks = (by.difference(from).inDays + 1) / 7;
    final perWeek = weeks <= 0 ? target : (target / weeks).round();
    final today = DateTime(now.year, now.month, now.day);
    final ready = target > 0 && !_busy;

    return SheetFrame(
      title: editing == null ? l10n.goalsNew : l10n.goalEditTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.goalSheetAmount, style: AppTypography.label),
          TextField(
            controller: _amount,
            autofocus: widget.initialAmount == null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTypography.headline,
            cursorColor: AppColors.ink,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '10000',
              hintStyle: AppTypography.headline.copyWith(color: AppColors.ink3),
              prefixText: r'R$ ',
              prefixStyle: AppTypography.headline,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s3,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(l10n.goalSheetBy, style: AppTypography.label),
          const SizedBox(height: AppSpacing.s2),
          if (editing == null) ...[
            // Three choices on one line, shrunk rather than cut on a
            // narrow phone.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AppSegmented(
                selected: _by,
                onSelected: (i) => i == 2
                    ? unawaited(_pickOther(from, _other ?? by))
                    : setState(() => _by = i),
                segments: [
                  AppSegment(label: l10n.goalByNextWeek),
                  AppSegment(label: l10n.goalByNextMonth),
                  AppSegment(label: l10n.goalByOther),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          SheetGroup(
            children: [
              SheetRow(
                iconData: AppIcons.calendar,
                label: l10n.artifactDeadline,
                value: dayName(l10n, by, now),
                onTap: () => unawaited(_pickOther(from, by)),
              ),
            ],
          ),
          if (target > 0) ...[
            const SizedBox(height: AppSpacing.s5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: AppIcon(
                    iconData: AppIcons.goal,
                    size: AppSpacing.s5,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.goalReadbackBy(
                          formatMoney(target),
                          shortDay(l10n, by),
                        ),
                        style: AppTypography.bodyStrong,
                      ),
                      Text(
                        editing != null
                            ? l10n.goalReadbackSince(
                                dayName(l10n, from, now),
                                formatMoney(perWeek),
                              )
                            : from == today
                            ? l10n.goalReadbackFromToday(formatMoney(perWeek))
                            : l10n.goalReadbackFromDay(
                                dayName(l10n, from, now),
                                formatMoney(perWeek),
                              ),
                        style: AppTypography.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: editing == null ? l10n.goalCreateObjective : l10n.commonSave,
            expand: true,
            onPressed: ready ? () => unawaited(_save(target, by)) : null,
          ),
        ],
      ),
    );
  }
}
