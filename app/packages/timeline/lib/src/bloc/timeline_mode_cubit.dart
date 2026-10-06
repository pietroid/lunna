import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the day is drawn.
enum TimelineMode {
  /// The tasks alone, in the order they are to be done, each as tall as it
  /// needs. Reordering here is reordering the queue.
  list,

  /// Everything on the calendar, as tall as its time, day after day.
  calendar,
}

/// {@template timeline_mode_cubit}
/// Which way the day is drawn, remembered on this device.
///
/// The phone's own choice rather than the account's: someone may plan in the
/// list on a laptop and live in the calendar on a phone. Nothing that cannot
/// be read or written here is worth an error, so a failure simply leaves the
/// mode as it was.
/// {@endtemplate}
class TimelineModeCubit extends Cubit<TimelineMode> {
  /// {@macro timeline_mode_cubit}
  TimelineModeCubit({TimelineMode initial = TimelineMode.calendar})
    : super(initial);

  static const _key = 'timeline.mode';

  /// Reads the mode this device last chose.
  Future<void> restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final mode = TimelineMode.values.where((it) => it.name == saved);
      if (mode.isNotEmpty && !isClosed) emit(mode.first);
    } on Object {
      // Nothing remembered is the same as nothing chosen.
    }
  }

  /// Draws the day as [mode], and remembers it.
  void choose(TimelineMode mode) {
    if (mode == state) return;

    emit(mode);
    unawaited(_save(mode));
  }

  Future<void> _save(TimelineMode mode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } on Object {
      // The choice still holds for as long as the app is open.
    }
  }
}
