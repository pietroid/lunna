import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:artifacts/src/view/sheet_rows.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// Asks for the day [artifact] is due by, as it is begun with none: the
/// day picked, or null when the sheet is closed, and then it is not begun.
Future<DateTime?> showStartSheet(BuildContext context, Artifact artifact) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => StartSheet(artifact: artifact),
  );
}

/// {@template start_sheet}
/// Beginning a delivery that has no day: its time runs from now to the end
/// of a deadline, so the deadline comes first.
///
/// Three days a person names without a calendar (in three days, a week,
/// two weeks), a week picked, and the calendar for any other; Começar
/// begins it with the one picked.
/// {@endtemplate}
class StartSheet extends StatefulWidget {
  /// {@macro start_sheet}
  const StartSheet({required this.artifact, this.initialDays = 7, super.key});

  /// The delivery being begun.
  final Artifact artifact;

  /// How many days out the picked day starts: a week.
  final int initialDays;

  @override
  State<StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<StartSheet> {
  static const _choices = [3, 7, 14];

  late final DateTime _today = () {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }();

  late DateTime _day = _in(widget.initialDays);

  DateTime _in(int days) =>
      DateTime(_today.year, _today.month, _today.day + days);

  Future<void> _pickOther() async {
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: _day,
      earliest: _today,
    );
    if (picked == null) return;
    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final other = !_choices.any((days) => _in(days) == _day);

    return SheetFrame(
      title: l10n.artifactStartTitle(widget.artifact.title),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.artifactStartBody,
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: AppSpacing.s4),
          SheetGroup(
            children: [
              for (final days in _choices)
                _Choice(
                  label: days % 7 == 0
                      ? l10n.artifactStartInWeeks(days ~/ 7)
                      : l10n.artifactStartInDays(days),
                  day: AppWheelPicker.dayLabel(l10n, _in(days), now: _today),
                  selected: _in(days) == _day,
                  onTap: () => setState(() => _day = _in(days)),
                ),
              _Choice(
                label: l10n.artifactStartOtherDay,
                day: other
                    ? AppWheelPicker.dayLabel(l10n, _day, now: _today)
                    : l10n.artifactStartOtherDayHint,
                selected: other,
                onTap: () => unawaited(_pickOther()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: l10n.artifactStart,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_day),
          ),
        ],
      ),
    );
  }
}

/// One day to pick: what it is called, the date, and a check when picked.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3 + 2,
        ),
        child: Row(
          children: [
            // The names are short; the day takes what is left.
            Text(label, style: AppTypography.body),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                day,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.label.copyWith(color: AppColors.ink2),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: AppSpacing.s5,
              child: selected
                  ? const AppIcon(
                      iconData: AppIcons.check,
                      size: AppSpacing.s5,
                      color: AppColors.accent,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
