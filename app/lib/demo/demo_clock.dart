import 'package:clock/clock.dart';

/// {@template demo_clock}
/// The hour the demo is lived at.
///
/// The landing page's demo is a working day, so it is shown at one: while a
/// demo is on screen the app's clock reads ten in the morning, today, in the
/// visitor's zone, and runs on from there. A visit at night would otherwise
/// open on "Boa noite" and a day already over.
///
/// It works through `package:clock`, which every widget and bloc reads, so
/// the app runs inside [around] (see `main.dart`). With no demo pinned the
/// clock is the one it wraps, to the microsecond.
/// {@endtemplate}
abstract final class DemoClock {
  /// The hour a pinned demo starts at.
  static const hour = 10;

  static Duration _shift = Duration.zero;
  static int _pins = 0;

  /// [outer], moved by the pin while a demo holds it.
  static Clock around(Clock outer) => Clock(() => outer.now().add(_shift));

  /// Moves the clock to [hour] o'clock today, until [unpin]. Pins nest: the
  /// clock moves on the first and comes back on the last.
  static void pin() {
    if (_pins++ > 0) return;
    final now = clock.now();
    _shift = DateTime(now.year, now.month, now.day, hour).difference(now);
  }

  /// Lets go of a [pin].
  static void unpin() {
    if (_pins == 0 || --_pins > 0) return;
    _shift = Duration.zero;
  }
}
