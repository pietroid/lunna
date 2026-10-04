import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template routines_page}
/// Rotina: the blocks that come back every day, drawn on the working day.
///
/// Three tabs, one per kind of day: every day, weekdays and the weekend.
/// Each is the day from seven to ten with its routines on it, the way the
/// week will actually look. Tapping an empty hour writes a routine down
/// there; tapping one opens it; holding one picks it up and moves it.
///
/// The repeating is Google's. Every routine is one recurring event, so
/// nothing here keeps a copy of anything: the list is read back after every
/// change, and the timeline picks the new days up like any fixed block.
/// {@endtemplate}
class RoutinesPage extends StatefulWidget {
  /// {@macro routines_page}
  const RoutinesPage({super.key});

  @override
  State<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends State<RoutinesPage> {
  RoutineDays _tab = RoutineDays.daily;
  List<Routine>? _routines;
  String? _failure;
  bool _busy = false;

  RoutinesRepository get _repository => context.read<RoutinesRepository>();

  @override
  void initState() {
    super.initState();
    unawaited(_run(_repository.fetchRoutines, refreshDay: false));
  }

  /// Runs one call that answers with every routine, and draws the answer.
  ///
  /// A change also refreshes the timeline, which draws the routine's days and
  /// is kept alive behind this screen.
  Future<void> _run(
    Future<List<Routine>> Function() call, {
    bool refreshDay = true,
  }) async {
    final timeline = context.read<TimelineBloc>();
    setState(() => _busy = true);

    try {
      final routines = await call();
      if (!mounted) return;
      setState(() {
        _routines = routines;
        _failure = null;
      });
      if (refreshDay) timeline.add(const TimelineRequested());
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failure = ChatFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(int startMinute) async {
    final draft = await _RoutineSheet.show(
      context,
      startMinute: startMinute,
      durationMinutes: 30,
    );
    if (draft == null || draft.delete) return;

    await _run(
      () => _repository.addRoutine(
        title: draft.title,
        time: _time(draft.startMinute),
        durationMinutes: draft.durationMinutes,
        days: _tab,
      ),
    );
  }

  Future<void> _open(Routine routine) async {
    final draft = await _RoutineSheet.show(
      context,
      title: routine.title,
      startMinute: routine.startMinute,
      durationMinutes: routine.durationMinutes,
      editing: true,
    );
    if (draft == null) return;

    if (draft.delete) {
      await _run(() => _repository.deleteRoutine(routine.id));
      return;
    }

    await _run(
      () => _repository.editRoutine(
        routine.id,
        title: draft.title == routine.title ? null : draft.title,
        time: draft.startMinute == routine.startMinute
            ? null
            : _time(draft.startMinute),
        durationMinutes: draft.durationMinutes == routine.durationMinutes
            ? null
            : draft.durationMinutes,
      ),
    );
  }

  Future<void> _move(Routine routine, int startMinute) async {
    if (startMinute == routine.startMinute) return;

    await _run(
      () => _repository.editRoutine(routine.id, time: _time(startMinute)),
    );
  }

  static String _time(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final routines = _routines;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text('Rotina', style: AppTypography.title),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.s5),
              child: SizedBox.square(
                dimension: AppSpacing.s4,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.ink3,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    0,
                    AppSpacing.s6,
                    AppSpacing.s2,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppSegmented(
                      selected: RoutineDays.values.indexOf(_tab),
                      onSelected: (index) =>
                          setState(() => _tab = RoutineDays.values[index]),
                      segments: [
                        for (final days in RoutineDays.values)
                          AppSegment(label: days.label),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    0,
                    AppSpacing.s6,
                    AppSpacing.s3,
                  ),
                  child: Text(
                    _failure == null
                        ? 'Toque num horário para criar. Segure um bloco '
                              'para mudar a hora.'
                        : '$_failure Toque para tentar de novo.',
                    style: AppTypography.label.copyWith(color: AppColors.ink3),
                  ),
                ),
                Expanded(
                  child: routines == null
                      ? const SizedBox.shrink()
                      : _DayGrid(
                          own: [
                            for (final routine in routines)
                              if (routine.days == _tab) routine,
                          ],
                          // Every-day routines happen on weekdays and weekends
                          // too, so those tabs show them, faded and left to
                          // their own tab to change.
                          context_: [
                            if (_tab != RoutineDays.daily)
                              for (final routine in routines)
                                if (routine.days == RoutineDays.daily) routine,
                          ],
                          onCreate: (minute) => unawaited(_create(minute)),
                          onOpen: (routine) => unawaited(_open(routine)),
                          onMove: (routine, minute) =>
                              unawaited(_move(routine, minute)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The working day, seven to ten, with the routines on it.
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.own,
    required this.context_,
    required this.onCreate,
    required this.onOpen,
    required this.onMove,
  });

  /// How tall a minute is. The whole day is a long scroll, not a squeeze.
  static const perMinute = 1.1;

  /// Where the day starts and ends, in minutes past midnight.
  static const int _first = 7 * 60;
  static const int _last = 22 * 60;

  /// How wide the hour labels on the left are.
  static const double _gutter = AppSpacing.s12;

  /// The tab's own routines.
  final List<Routine> own;

  /// Routines from another tab that also happen on these days.
  final List<Routine> context_;

  final ValueChanged<int> onCreate;
  final ValueChanged<Routine> onOpen;
  final void Function(Routine routine, int startMinute) onMove;

  static double _y(int minute) => (minute - _first) * perMinute;

  @override
  Widget build(BuildContext context) {
    const height = (_last - _first) * perMinute;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s2,
        AppSpacing.s6,
        AppSpacing.s12,
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var hour = 7; hour <= 22; hour++)
              Positioned(
                top: _y(hour * 60) - AppSpacing.s2,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: _gutter,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        height: AppSpacing.s4,
                        color: AppColors.line,
                      ),
                    ),
                  ],
                ),
              ),
            // Empty time: a tap writes a routine down at the nearest quarter.
            Positioned.fill(
              left: _gutter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final minute = _first + details.localPosition.dy / perMinute;
                  final quarter = (minute / 15).floor() * 15;
                  onCreate(quarter.clamp(_first, _last - 15));
                },
              ),
            ),
            for (final routine in context_) _placed(routine, faded: true),
            for (final routine in own) _placed(routine),
          ],
        ),
      ),
    );
  }

  Widget _placed(Routine routine, {bool faded = false}) {
    return _RoutineBlock(
      key: ValueKey('${routine.id}-${routine.startMinute}'),
      routine: routine,
      faded: faded,
      top: _y(routine.startMinute),
      height: routine.durationMinutes * perMinute,
      left: _gutter + AppSpacing.s2,
      onTap: faded ? null : () => onOpen(routine),
      onMoved: faded
          ? null
          : (dy) {
              final moved = routine.startMinute + dy / perMinute;
              final snapped = (moved / 5).round() * 5;
              onMove(
                routine,
                snapped.clamp(_first, _last - routine.durationMinutes),
              );
            },
    );
  }
}

/// One routine on the grid, which can be held and dragged up or down.
class _RoutineBlock extends StatefulWidget {
  const _RoutineBlock({
    required this.routine,
    required this.faded,
    required this.top,
    required this.height,
    required this.left,
    required this.onTap,
    required this.onMoved,
    super.key,
  });

  final Routine routine;
  final bool faded;
  final double top;
  final double height;
  final double left;
  final VoidCallback? onTap;

  /// Called with how far it was carried, in pixels, when it is let go.
  final ValueChanged<double>? onMoved;

  @override
  State<_RoutineBlock> createState() => _RoutineBlockState();
}

class _RoutineBlockState extends State<_RoutineBlock> {
  double _dy = 0;
  bool _lifted = false;

  /// The hour it would land on if it were let go now.
  String get _label {
    final minutes = _lifted
        ? ((widget.routine.startMinute + _dy / _DayGrid.perMinute) / 5)
                  .round() *
              5
        : widget.routine.startMinute;

    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.height < AppSpacing.s12;
    final body = Container(
      decoration: BoxDecoration(
        color: _lifted ? AppColors.fillStrong : AppColors.routineFill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: compact ? 0 : AppSpacing.s2,
      ),
      alignment: compact ? Alignment.centerLeft : Alignment.topLeft,
      child: Row(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.routine.title,
              style: AppTypography.label.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            _label,
            style: AppTypography.label.copyWith(color: AppColors.ink3),
          ),
        ],
      ),
    );

    return Positioned(
      top: widget.top + _dy,
      left: widget.left,
      right: 0,
      height: widget.height.clamp(AppSpacing.s6, double.infinity),
      child: Opacity(
        opacity: widget.faded ? 0.45 : 1,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPressStart: widget.onMoved == null
              ? null
              : (_) {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _lifted = true);
                },
          onLongPressMoveUpdate: widget.onMoved == null
              ? null
              : (details) => setState(() => _dy = details.offsetFromOrigin.dy),
          onLongPressEnd: widget.onMoved == null
              ? null
              : (_) {
                  final dy = _dy;
                  setState(() {
                    _lifted = false;
                    _dy = 0;
                  });
                  widget.onMoved!(dy);
                },
          child: body,
        ),
      ),
    );
  }
}

/// What the routine sheet came back with.
class _RoutineDraft {
  const _RoutineDraft({
    required this.title,
    required this.startMinute,
    required this.durationMinutes,
  }) : delete = false;

  const _RoutineDraft.deleted()
    : title = '',
      startMinute = 0,
      durationMinutes = 0,
      delete = true;

  final String title;
  final int startMinute;
  final int durationMinutes;
  final bool delete;
}

/// A routine, written down or opened: its name, its hour and its length.
class _RoutineSheet extends StatefulWidget {
  const _RoutineSheet({
    required this.startMinute,
    required this.durationMinutes,
    this.title,
    this.editing = false,
  });

  final String? title;
  final int startMinute;
  final int durationMinutes;

  /// Whether it already exists, which is what offers the delete.
  final bool editing;

  static Future<_RoutineDraft?> show(
    BuildContext context, {
    required int startMinute,
    required int durationMinutes,
    String? title,
    bool editing = false,
  }) {
    return showModalBottomSheet<_RoutineDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => _RoutineSheet(
        title: title,
        startMinute: startMinute,
        durationMinutes: durationMinutes,
        editing: editing,
      ),
    );
  }

  @override
  State<_RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<_RoutineSheet> {
  late final _controller = TextEditingController(text: widget.title);
  late int _start = widget.startMinute;
  late int _duration = widget.durationMinutes;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final picked = await AppWheelPicker.time(
      context,
      initial: midnight.add(Duration(minutes: _start)),
      earliest: midnight,
    );
    if (picked == null) return;

    setState(() => _start = picked.hour * 60 + picked.minute);
  }

  Future<void> _pickDuration() async {
    final picked = await AppWheelPicker.duration(
      context,
      initial: Duration(minutes: _duration),
    );
    if (picked == null || picked.inMinutes < 5) return;

    setState(() => _duration = picked.inMinutes);
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    Navigator.of(context).pop(
      _RoutineDraft(
        title: title,
        startMinute: _start,
        durationMinutes: _duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${(_start ~/ 60).toString().padLeft(2, '0')}:'
        '${(_start % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.cardRadius),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s4,
              AppSpacing.s6,
              AppSpacing.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: !widget.editing,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body,
                  cursorColor: AppColors.ink,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    hintText: 'Almoço, rotina da manhã…',
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.ink3,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    AppPillButton(
                      iconData: AppIcons.time,
                      label: time,
                      onPressed: _pickTime,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    AppPillButton(
                      iconData: AppIcons.timer,
                      label: formatDuration(Duration(minutes: _duration)),
                      onPressed: _pickDuration,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s5),
                AppButton(text: 'Salvar', expand: true, onPressed: _save),
                if (widget.editing) ...[
                  const SizedBox(height: AppSpacing.s2),
                  AppButton.text(
                    text: 'Excluir rotina',
                    color: AppColors.dangerInk,
                    expand: true,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _RoutineDraft.deleted()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
