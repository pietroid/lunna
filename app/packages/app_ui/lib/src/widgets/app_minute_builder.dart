import 'dart:async';

import 'package:app_ui/app_ui.dart';

/// {@template app_minute_builder}
/// Rebuilds on the minute boundary, and not once in between.
///
/// Anything that reads the wall clock and is left on screen goes stale: a
/// greeting that still says "Bom dia" at half past twelve is worse than no
/// greeting, and it sits next to a clock that would be proving it wrong.
/// Ticking on the boundary rather than every second keeps the screen still
/// for a minute at a time.
/// {@endtemplate}
class AppMinuteBuilder extends StatefulWidget {
  /// {@macro app_minute_builder}
  const AppMinuteBuilder({required this.builder, super.key});

  /// Called with the current time, once per minute.
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<AppMinuteBuilder> createState() => _AppMinuteBuilderState();
}

class _AppMinuteBuilderState extends State<AppMinuteBuilder> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _schedule();
  }

  void _schedule() {
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour,
    ).add(Duration(minutes: _now.minute + 1));

    _timer = Timer(next.difference(_now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
