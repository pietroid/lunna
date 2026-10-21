import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that writes a goal down.
Future<void> showGoalSheet(
  BuildContext context, {
  required DateTime now,
  int initialAmount = 8000,
  bool initialNext = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => GoalSheet(
      now: now,
      initialAmount: initialAmount,
      initialNext: initialNext,
    ),
  );
}

/// {@template goal_sheet}
/// A goal in four choices: what it measures, how much, over what stretch,
/// and from when.
///
/// The smallest goal that says something: an amount of money, or a count
/// of one kind of delivery, per week or per month. One that starts next
/// month waits, drawn quiet among the goals, and begins counting on its
/// first day. A line at the foot reads it back as a sentence.
/// {@endtemplate}
class GoalSheet extends StatefulWidget {
  /// {@macro goal_sheet}
  const GoalSheet({
    required this.now,
    this.initialAmount = 8000,
    this.initialNext = false,
    super.key,
  });

  /// The moment it is drawn at.
  final DateTime now;

  /// The amount it starts with, in reais.
  final int initialAmount;

  /// Whether it starts on next month rather than this one.
  final bool initialNext;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  GoalKind _kind = GoalKind.money;
  GoalPeriod _period = GoalPeriod.month;
  late bool _next = widget.initialNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.now;
    final nextMonth = DateTime(now.year, now.month + 1);
    final month = monthName(l10n, _next ? nextMonth : now);
    final amount = formatMoney(widget.initialAmount);

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
          _Line(
            label: l10n.goalAmount,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: Text(amount, style: AppTypography.title),
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
                  label: l10n.goalNextMonth(monthName(l10n, nextMonth)),
                ),
              ],
            ),
          ),
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
                      l10n.goalReadbackMoney(amount, month),
                      style: AppTypography.bodyStrong,
                    ),
                    if (_next)
                      Text(
                        l10n.goalReadbackFuture(month),
                        style: AppTypography.label,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: l10n.goalCreate,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
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
