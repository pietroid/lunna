import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that writes a goal down.
///
/// The sheet is its own route, so it is handed the cubit it writes with.
Future<void> showGoalSheet(
  BuildContext context, {
  GoalKind kind = GoalKind.money,
  int? amount,
}) {
  final cubit = context.read<ArtifactsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: GoalSheet(initialKind: kind, initialAmount: amount),
    ),
  );
}

/// {@template goal_sheet}
/// A goal in four choices: what it measures, how much, over what stretch,
/// and from when.
///
/// The smallest goal that says something: an amount of money, or a count
/// of one kind of delivery, per week or per month. One that starts with the
/// next stretch waits, drawn quiet among the goals, and begins counting on
/// its first day. A line at the foot reads it back as a sentence.
/// {@endtemplate}
class GoalSheet extends StatefulWidget {
  /// {@macro goal_sheet}
  const GoalSheet({
    this.initialKind = GoalKind.money,
    this.initialAmount,
    super.key,
  });

  /// What it measures when it opens.
  final GoalKind initialKind;

  /// How much it asks for when it opens.
  final int? initialAmount;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  late GoalKind _kind = widget.initialKind;
  GoalPeriod _period = GoalPeriod.month;
  bool _next = false;
  String? _typeId;
  late final _amount = TextEditingController(
    text: widget.initialAmount?.toString(),
  );
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(CatalogType? type, int target) async {
    final cubit = context.read<ArtifactsCubit>();
    setState(() => _busy = true);
    final made = await cubit.addGoal(
      kind: _kind,
      target: target,
      period: _period,
      type: type,
      next: _next,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (made) unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final types = context
        .watch<ArtifactsCubit>()
        .state
        .catalog
        .expand((c) => c.types)
        .toList();
    final money = _kind == GoalKind.money;
    final type =
        types.where((t) => t.id == _typeId).firstOrNull ?? types.firstOrNull;
    final month = monthName(
      l10n,
      _next ? DateTime(now.year, now.month + 1) : now,
    );
    final target = int.tryParse(_amount.text.trim()) ?? 0;
    final amount = money ? formatMoney(target) : '$target';
    final weekly = _period == GoalPeriod.week;
    final ready = target > 0 && (money || type != null) && !_busy;

    return SheetFrame(
      title: l10n.goalNew,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Line(
            label: l10n.goalSheetKind,
            child: AppSegmented(
              selected: _kind.index,
              onSelected: (i) => setState(() => _kind = GoalKind.values[i]),
              segments: [
                AppSegment(label: l10n.goalKindMoney),
                AppSegment(label: l10n.goalKindCount),
              ],
            ),
          ),
          if (!money)
            if (types.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                child: Text(
                  l10n.goalCountNeedsType,
                  style: AppTypography.label.copyWith(color: AppColors.ink2),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: AppSegmented(
                    selected: types.indexOf(type!),
                    onSelected: (i) => setState(() => _typeId = types[i].id),
                    segments: [
                      for (final it in types) AppSegment(label: it.name),
                    ],
                  ),
                ),
              ),
          _Line(
            label: l10n.goalAmount,
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: TextField(
                controller: _amount,
                autofocus: widget.initialAmount == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.end,
                style: AppTypography.title,
                cursorColor: AppColors.ink,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration.collapsed(
                  hintText: money ? '8000' : '3',
                  hintStyle: AppTypography.title.copyWith(
                    color: AppColors.ink3,
                  ),
                ).copyWith(prefixText: money ? r'R$ ' : null),
              ),
            ),
          ),
          _Line(
            label: l10n.goalPer,
            child: AppSegmented(
              selected: _period.index,
              onSelected: (i) => setState(() => _period = GoalPeriod.values[i]),
              segments: [
                AppSegment(label: l10n.goalPerWeek),
                AppSegment(label: l10n.goalPerMonth),
              ],
            ),
          ),
          _Line(
            label: l10n.goalWhen,
            child: AppSegmented(
              selected: _next ? 1 : 0,
              onSelected: (i) => setState(() => _next = i == 1),
              segments: [
                AppSegment(label: l10n.goalNow),
                AppSegment(
                  label: weekly
                      ? l10n.goalNextWeek
                      : l10n.goalNextMonth(
                          monthName(l10n, DateTime(now.year, now.month + 1)),
                        ),
                ),
              ],
            ),
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
                        money
                            ? weekly
                                  ? l10n.goalReadbackMoneyWeek(amount)
                                  : l10n.goalReadbackMoney(amount, month)
                            : weekly
                            ? l10n.goalReadbackCountWeek(
                                type?.name ?? '',
                                amount,
                              )
                            : l10n.goalReadbackCountMonth(
                                type?.name ?? '',
                                amount,
                                month,
                              ),
                        style: AppTypography.bodyStrong,
                      ),
                      if (_next)
                        Text(
                          weekly
                              ? l10n.goalReadbackFutureWeek
                              : l10n.goalReadbackFuture(month),
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
            text: l10n.goalCreate,
            expand: true,
            onPressed: ready
                ? () => unawaited(_save(money ? null : type, target))
                : null,
          ),
        ],
      ),
    );
  }
}

/// One choice of the goal: its name, and the control that makes it.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          child,
        ],
      ),
    );
  }
}
