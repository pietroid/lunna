import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Asks for the timeline again on each minute boundary while the app is in
/// sight, and draws nothing.
///
/// Which list a timed card is in is worked out from the clock, on the server,
/// when the list is read. So a card only walks into Agora as its hour comes
/// round if somebody asks for the list again: this is the asking, and it is
/// the whole of the minute-by-minute routine the timeline needs.
///
/// While the app is hidden (another tab in front, the phone locked) it asks
/// nothing: every read keeps the database awake, and a screen nobody sees has
/// no use for the minute. Shown again, it asks at once, so the day is the
/// clock's before anybody can read it, and goes back to the minute.
///
/// It is a widget with its own timer rather than a rebuild hook, because the
/// fetch has to happen on the tick and not on the rebuild. Asking from inside
/// a build would ask again for every state the answer produced.
class MinuteRefresh extends StatefulWidget {
  /// Calls [onRefresh] on every minute boundary while the app is shown.
  const MinuteRefresh({required this.onRefresh, super.key});

  /// Asks for the timeline again.
  final VoidCallback onRefresh;

  @override
  State<MinuteRefresh> createState() => _MinuteRefreshState();
}

class _MinuteRefreshState extends State<MinuteRefresh> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _stop, onShow: _resume);
    _schedule();
  }

  /// Wakes on the next minute boundary, not a minute from now, so the list
  /// turns over at the same moment the clock above it does.
  void _schedule() {
    _timer?.cancel();
    final now = clock.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: now.minute + 1));

    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      widget.onRefresh();
      _schedule();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _resume() {
    if (!mounted) return;
    widget.onRefresh();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
