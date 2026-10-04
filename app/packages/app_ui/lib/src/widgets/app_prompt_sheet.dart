import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// What the creation sheet came back with.
///
/// Everything needed to give something an hour, and nothing else. A flexible
/// block leaves [startTime] null and takes whatever slot the day has going;
/// a fixed one carries the hour the user picked.
class AppPromptResult {
  /// Creates a result.
  const AppPromptResult({
    required this.text,
    required this.duration,
    required this.fixed,
    this.startTime,
  });

  /// What the user wrote.
  final String text;

  /// How long it takes.
  final Duration duration;

  /// Whether the hour is the point of it.
  final bool fixed;

  /// The hour, when the user picked one.
  final DateTime? startTime;
}

/// {@template app_prompt_sheet}
/// The sheet the orb opens on Tempo: one line of text, and when it happens.
///
/// It is the whole of planning, collapsed into one screen. Type what it is,
/// say how long it takes, and the line underneath says what hour that works
/// out to. Tapping the check puts it on the timeline. There is no
/// conversation, no proposal and nothing to accept, because there is nothing
/// left to decide by the time the sheet closes.
///
/// Flexible is the default and means "in that order, whenever it fits". Fixed
/// means the hour is the point of it, and is the only case where the user is
/// asked to name one. The day and the hour are each their own pill, so a
/// block next week is as easy to write down as one this afternoon.
///
/// Opened from a tap on a full hour of empty room, it starts fixed at that
/// hour, which is what tapping an hour means.
///
/// On Coisas the same sheet asks without the clock: no flexible or fixed, no
/// hour, only what it is and how long it will take once it is on the day.
/// {@endtemplate}
class AppPromptSheet extends StatefulWidget {
  /// {@macro app_prompt_sheet}
  const AppPromptSheet({
    this.previewFor,
    this.initialText,
    this.initialDuration,
    this.initialStart,
    super.key,
  });

  /// When something of this length would land, if it were added now.
  ///
  /// Passed in rather than worked out here: the sheet knows how to ask a
  /// question and nothing at all about what is already on the day. Null asks
  /// without the clock at all, which is how Coisas writes something down.
  final DateTime Function(Duration duration)? previewFor;

  /// What the field starts with, when something is being edited.
  final String? initialText;

  /// The length it starts with, when something is being edited.
  final Duration? initialDuration;

  /// The hour it starts fixed at, when the sheet was opened on one.
  ///
  /// Only read when [previewFor] is given: without the clock there is no
  /// hour to start at.
  final DateTime? initialStart;

  /// The length something has before anyone has said otherwise.
  static const defaultDuration = Duration(minutes: 30);

  /// The ways the sheet asks what the user wants.
  ///
  /// All ten mean the same thing. They exist so that opening the sheet twice
  /// in a row does not feel like opening the same drawer twice.
  static const hints = <String>[
    'O que precisa ser feito?',
    'No que vamos trabalhar?',
    'O que entra no dia?',
    'Por onde começamos?',
    'O que está na sua cabeça?',
    'Me conta o que precisa.',
    'Qual é a próxima?',
    'O que resolvemos hoje?',
    'Escreve aí.',
    'Pode falar.',
  ];

  /// Opens the sheet and resolves with what was confirmed, or null if it was
  /// dismissed without sending.
  static Future<AppPromptResult?> show(
    BuildContext context, {
    DateTime Function(Duration duration)? previewFor,
    String? initialText,
    Duration? initialDuration,
    DateTime? initialStart,
  }) {
    return showModalBottomSheet<AppPromptResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => AppPromptSheet(
        previewFor: previewFor,
        initialText: initialText,
        initialDuration: initialDuration,
        initialStart: initialStart,
      ),
    );
  }

  @override
  State<AppPromptSheet> createState() => _AppPromptSheetState();
}

class _AppPromptSheetState extends State<AppPromptSheet> {
  late final _controller = TextEditingController(text: widget.initialText);
  late final String _hint =
      AppPromptSheet.hints[math.Random().nextInt(AppPromptSheet.hints.length)];

  late Duration _duration =
      widget.initialDuration ?? AppPromptSheet.defaultDuration;

  /// Whether the sheet is asking about the clock at all.
  bool get _timed => widget.previewFor != null;
  late bool _fixed = _timed && widget.initialStart != null;

  /// The hour a fixed block was given. Null while it is still flexible.
  late DateTime? _startTime = _fixed ? widget.initialStart : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// When this would run, as the line under the field reads it.
  ///
  /// A fixed block says the hour it was given; a flexible one asks where it
  /// would land. Either way it is a span, because that is what a card on the
  /// timeline will say once this is one.
  ({DateTime start, DateTime end}) get _span {
    final start = _startTime ?? widget.previewFor!(_duration);

    return (start: start, end: start.add(_duration));
  }

  /// Turning "fixo" on has to name an hour, because that is what fixed means.
  void _setFixed({required bool fixed}) {
    setState(() {
      _fixed = fixed;
      _startTime = fixed ? widget.previewFor!(_duration) : null;
    });
  }

  Future<void> _pickDuration() async {
    final picked = await AppWheelPicker.duration(
      context,
      initial: _duration,
    );
    if (picked == null || picked == Duration.zero) return;

    setState(() => _duration = picked);
  }

  /// The day, and the hour with it, since the hour may not be free on
  /// every day.
  Future<void> _pickDay() async {
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: _span.start,
      earliest: DateTime.now(),
    );
    if (picked == null) return;

    setState(() => _startTime = picked);
  }

  /// The hour on the day already picked.
  Future<void> _pickTime() async {
    final now = DateTime.now();
    final start = _span.start;
    final today =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    // The wheel only knows the clock, so the day is put back on afterwards.
    // Earlier than now only binds today.
    final picked = await AppWheelPicker.time(
      context,
      initial: start,
      earliest: today ? now : DateTime(start.year, start.month, start.day),
    );
    if (picked == null) return;

    setState(
      () => _startTime = DateTime(
        start.year,
        start.month,
        start.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    Navigator.of(context).pop(
      AppPromptResult(
        text: text,
        duration: _duration,
        fixed: _timed && _fixed,
        startTime: _timed && _fixed ? _span.start : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet sits on the keyboard rather than under it, so the field is
      // still visible the moment it takes focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s3,
              AppSpacing.s5,
              AppSpacing.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  controller: _controller,
                  hint: _hint,
                  onSubmit: _submit,
                ),
                const SizedBox(height: AppSpacing.s2),
                if (_timed) ...[
                  _Controls(
                    fixed: _fixed,
                    duration: _duration,
                    onFixed: (value) => _setFixed(fixed: value),
                    onDuration: _pickDuration,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Preview(
                    span: _span,
                    editable: _fixed,
                    onDay: _pickDay,
                    onTime: _pickTime,
                    send: _Send(
                      controller: _controller,
                      onPressed: _submit,
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      AppPillButton(
                        iconData: AppIcons.timer,
                        label: formatDuration(_duration),
                        onPressed: _pickDuration,
                      ),
                      const Spacer(),
                      _Send(controller: _controller, onPressed: _submit),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The field: no fill, no border, nothing drawn around it.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => onSubmit(),
      cursorColor: AppColors.ink,
      cursorWidth: 1.5,
      cursorRadius: const Radius.circular(AppSpacing.s1),
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      ),
    );
  }
}

/// The one line of controls: flexible or fixed, and how long.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.fixed,
    required this.duration,
    required this.onFixed,
    required this.onDuration,
  });

  final bool fixed;
  final Duration duration;
  final ValueChanged<bool> onFixed;
  final VoidCallback onDuration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppSegmented(
          selected: fixed ? 1 : 0,
          onSelected: (index) => onFixed(index == 1),
          segments: const [
            AppSegment(label: 'Flexível', iconData: AppIcons.time),
            AppSegment(label: 'Fixo', iconData: AppIcons.pin),
          ],
        ),
        const SizedBox(width: AppSpacing.s2),
        AppPillButton(
          iconData: AppIcons.timer,
          label: formatDuration(duration),
          onPressed: onDuration,
        ),
      ],
    );
  }
}

/// The line that says when this will happen, and the check that makes it so.
///
/// A flexible block reads back where it would land, quietly, because the app
/// worked it out and it cannot be changed here. A fixed one is the user's own
/// answer: the day and the hour, each a pill that opens its picker.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.span,
    required this.editable,
    required this.onDay,
    required this.onTime,
    required this.send,
  });

  final ({DateTime start, DateTime end}) span;

  /// Whether the hour is the user's to choose, which only a fixed block is.
  final bool editable;

  final VoidCallback onDay;
  final VoidCallback onTime;
  final Widget send;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: editable
              ? Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    AppPillButton(
                      iconData: AppIcons.calendar,
                      label: AppWheelPicker.dayLabel(span.start),
                      onPressed: onDay,
                    ),
                    AppPillButton(
                      iconData: AppIcons.time,
                      label: '${_hhmm(span.start)}–${_hhmm(span.end)}',
                      onPressed: onTime,
                    ),
                  ],
                )
              : Text(
                  '${_hhmm(span.start)}${_day(span.start)}',
                  style: AppTypography.body.copyWith(color: AppColors.ink3),
                ),
        ),
        send,
      ],
    );
  }

  /// ", amanhã" when the hour has run past midnight, and nothing otherwise.
  static String _day(DateTime start) {
    final label = AppWheelPicker.dayLabel(start);
    return label == 'Hoje' ? '' : ', ${label.toLowerCase()}';
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}

/// The send: a bare check that lights up once there is something to send.
class _Send extends StatelessWidget {
  const _Send({required this.controller, required this.onPressed});

  final TextEditingController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final enabled = value.text.trim().isNotEmpty;

        return SizedBox.square(
          dimension: AppSpacing.tapTarget,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              customBorder: const CircleBorder(),
              child: Center(
                child: AnimatedOpacity(
                  opacity: enabled ? 1 : 0.35,
                  duration: const Duration(milliseconds: 160),
                  child: const AppIcon(
                    iconData: AppIcons.check,
                    size: AppSpacing.s5,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "45 min", "1 h", "1h30", the way every length in the app is written.
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';

  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours h';

  return '${hours}h${rest.toString().padLeft(2, '0')}';
}
