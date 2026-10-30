import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:cycle/src/cycle_cubit.dart';
import 'package:cycle/src/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens [DayOffSheet], handed the page's [CycleCubit].
Future<void> showDayOffSheet(BuildContext context) {
  final cubit = context.read<CycleCubit>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const DayOffSheet(),
    ),
  );
}

/// Opens [RemoveDayOffSheet] on [day], handed the page's [CycleCubit].
Future<void> showRemoveDayOffSheet(BuildContext context, DayOff day) {
  final cubit = context.read<CycleCubit>();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: RemoveDayOffSheet(day: day),
    ),
  );
}

/// {@template day_off_sheet}
/// A date off written down from Folgas' +: the day (tomorrow unless
/// changed, on the date wheel) and an optional name, posted to
/// `/rhythm/days-off`.
/// {@endtemplate}
class DayOffSheet extends StatefulWidget {
  /// {@macro day_off_sheet}
  const DayOffSheet({super.key});

  @override
  State<DayOffSheet> createState() => _DayOffSheetState();
}

class _DayOffSheetState extends State<DayOffSheet> {
  final _name = TextEditingController();
  late DateTime _day = () {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day + 1);
  }();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await AppWheelPicker.date(
      context,
      initial: _day,
      first: today,
      last: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CycleCubit>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _SheetFrame(
        title: l10n.daysOffAddTitle,
        children: [
          AppListItem(
            title: l10n.cycleDayTitle(_day),
            iconData: AppIcons.calendar,
            onTap: () => unawaited(_pick()),
          ),
          const SizedBox(height: AppSpacing.s3),
          AppTextField(
            controller: _name,
            hintText: l10n.daysOffAddName,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            expand: true,
            text: l10n.daysOffAddConfirm,
            onPressed: () {
              unawaited(cubit.addDayOff(_day, _name.text.trim()));
              unawaited(Navigator.of(context).maybePop());
            },
          ),
        ],
      ),
    );
  }
}

/// {@template remove_day_off_sheet}
/// A date off tapped in Folgas: its name, and one button that takes it
/// away, so the day is what the weekend and the cycle make it again.
/// {@endtemplate}
class RemoveDayOffSheet extends StatelessWidget {
  /// {@macro remove_day_off_sheet}
  const RemoveDayOffSheet({required this.day, super.key});

  /// The date written down.
  final DayOff day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CycleCubit>();

    return _SheetFrame(
      title: day.title.isEmpty
          ? l10n.cycleDayTitle(day.day)
          : l10n.daysOffEntry(day.day, day.title),
      children: [
        AppButton(
          expand: true,
          variant: AppButtonVariant.secondary,
          text: l10n.daysOffRemove,
          onPressed: () {
            unawaited(cubit.remove([day.id]));
            unawaited(Navigator.of(context).maybePop());
          },
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          l10n.daysOffRemoveHelp,
          style: AppTypography.label.copyWith(color: AppColors.ink3),
        ),
      ],
    );
  }
}

/// A sheet's paper, title and close, as the cycle's day sheet draws them.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: Text(title, style: AppTypography.title)),
                  AppIconButton(
                    iconData: AppIcons.close,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
