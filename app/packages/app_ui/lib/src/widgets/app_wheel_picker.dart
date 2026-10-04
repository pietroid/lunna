import 'package:app_ui/app_ui.dart';
import 'package:flutter/cupertino.dart';

/// {@template app_wheel_picker}
/// The sheet behind a duration or an hour: one wheel and two buttons.
///
/// Cupertino's wheels rather than Material's dialogs, because both of these
/// answer the same kind of question — a number on a dial, five minutes at a
/// time — and a wheel says that while a dialog full of fields does not.
/// {@endtemplate}
abstract final class AppWheelPicker {
  /// Minutes are picked five at a time, which is also how the day is laid out.
  static const minuteInterval = 5;

  /// Asks for a length of time, starting at [initial].
  ///
  /// Resolves with what was confirmed, or null if the sheet was dismissed.
  static Future<Duration?> duration(
    BuildContext context, {
    required Duration initial,
  }) {
    var picked = initial;

    return _show<Duration>(
      context,
      title: 'Quanto tempo leva?',
      onConfirm: () => picked,
      wheel: CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.hm,
        minuteInterval: minuteInterval,
        initialTimerDuration: initial,
        onTimerDurationChanged: (value) => picked = value,
      ),
    );
  }

  /// Asks for an hour, starting at [initial] and never before [earliest].
  static Future<DateTime?> time(
    BuildContext context, {
    required DateTime initial,
    required DateTime earliest,
  }) {
    final start = onInterval(initial.isBefore(earliest) ? earliest : initial);
    var picked = start;

    return _show<DateTime>(
      context,
      title: 'A que horas?',
      onConfirm: () => picked,
      wheel: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        minimumDate: earliest,
        initialDateTime: start,
        minuteInterval: minuteInterval,
        use24hFormat: true,
        onDateTimeChanged: (value) => picked = value,
      ),
    );
  }

  /// Asks for a day and an hour, starting at [initial].
  ///
  /// Two wheels side by side, the day and the hour. The day wheel names days
  /// the way a person does, "Hoje", "Amanhã", "qui, 2 out", and runs [days]
  /// ahead, a year unless told otherwise. [earliest] only binds on the day it
  /// falls on: an hour tomorrow may be earlier on the clock than now.
  static Future<DateTime?> dayAndTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime earliest,
    int days = 365,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => _DayAndTime(
        initial: initial,
        earliest: earliest,
        days: days,
      ),
    );
  }

  /// [at] moved up to the next mark on the wheel, which only stops every
  /// [minuteInterval] minutes and refuses to start between two.
  static DateTime onInterval(DateTime at) {
    final minute = DateTime(at.year, at.month, at.day, at.hour, at.minute);
    final over = minute.minute % minuteInterval;
    if (over == 0 && minute == at) return minute;

    return minute.add(Duration(minutes: minuteInterval - over));
  }

  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const _months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  /// "Hoje", "Amanhã", or "qui, 2 out": a day the way a person names it.
  static String dayLabel(DateTime day, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final offset = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (offset == 0) return 'Hoje';
    if (offset == 1) return 'Amanhã';

    final weekday = _weekdays[day.weekday - 1];
    return '$weekday, ${day.day} ${_months[day.month - 1]}';
  }

  static Future<T?> _show<T>(
    BuildContext context, {
    required String title,
    required Widget wheel,
    required T Function() onConfirm,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (sheetContext) => _Sheet(
        title: title,
        wheel: wheel,
        onConfirm: () => Navigator.of(sheetContext).pop(onConfirm()),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.wheel,
    required this.onConfirm,
  });

  final String title;
  final Widget wheel;
  final VoidCallback onConfirm;

  /// How tall the wheel's area is.
  static const height = 180.0;

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
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.title),
              SizedBox(
                height: height,
                // The wheel draws its own text, so the app's type has to be
                // handed to it rather than inherited from the sheet.
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  child: wheel,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton(
                text: 'Confirmar',
                onPressed: onConfirm,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAndTime extends StatefulWidget {
  const _DayAndTime({
    required this.initial,
    required this.earliest,
    required this.days,
  });

  final DateTime initial;
  final DateTime earliest;
  final int days;

  @override
  State<_DayAndTime> createState() => _DayAndTimeState();
}

class _DayAndTimeState extends State<_DayAndTime> {
  static const _itemExtent = 36.0;

  late final DateTime _today = _dateOf(DateTime.now());
  late int _offset = _dayOffset(widget.initial).clamp(0, widget.days - 1);
  late DateTime _picked = widget.initial;
  late final _days = FixedExtentScrollController(initialItem: _offset);

  static DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);

  /// Days from today to [at], by the calendar rather than by 24 hours, so a
  /// change of clocks in between does not move the answer.
  int _dayOffset(DateTime at) {
    final day = _dateOf(at);
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(_today.year, _today.month, _today.day)).inDays;
  }

  DateTime _dayAt(int offset) =>
      DateTime(_today.year, _today.month, _today.day + offset);

  /// The hour on the picked day, held at the same clock reading when the day
  /// changes.
  DateTime get _value {
    final day = _dayAt(_offset);
    return DateTime(
      day.year,
      day.month,
      day.day,
      _picked.hour,
      _picked.minute,
    );
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onEarliestDay = _dayAt(_offset) == _dateOf(widget.earliest);
    final value = AppWheelPicker.onInterval(
      onEarliestDay && _value.isBefore(widget.earliest)
          ? widget.earliest
          : _value,
    );

    return _Sheet(
      title: 'Quando?',
      onConfirm: () => Navigator.of(context).pop(value),
      wheel: Row(
        children: [
          Expanded(
            flex: 3,
            child: CupertinoPicker.builder(
              scrollController: _days,
              itemExtent: _itemExtent,
              childCount: widget.days,
              onSelectedItemChanged: (offset) =>
                  setState(() => _offset = offset),
              itemBuilder: (context, offset) => Center(
                child: Text(
                  AppWheelPicker.dayLabel(_dayAt(offset)),
                  style: const TextStyle(color: AppColors.ink, fontSize: 20),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: CupertinoDatePicker(
              // Rebuilt per day, because the earliest hour only applies on
              // the day it falls on.
              key: ValueKey(_offset),
              mode: CupertinoDatePickerMode.time,
              minimumDate: onEarliestDay ? widget.earliest : null,
              initialDateTime: value,
              minuteInterval: AppWheelPicker.minuteInterval,
              use24hFormat: true,
              onDateTimeChanged: (picked) => _picked = picked,
            ),
          ),
        ],
      ),
    );
  }
}
