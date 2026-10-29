import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timeline/timeline.dart';

/// {@template live_activity}
/// The running block on the Lock Screen and in the Dynamic Island (iOS 17
/// and later): the `BlockActivity` extension in `ios/`, started, updated and
/// ended from here through the `lunna/live_activity` channel.
///
/// It is told about the block only when what it shows changes: begun,
/// paused, resumed, given time, gone past its end, finished. Its timers
/// count by themselves. Its buttons post the card's own routes from the
/// app's process (`BlockIntent` in Swift) and redraw it from the answer, so
/// they work with the app closed; [changes] tells the app when they did.
///
/// Anything that goes wrong is logged and dropped: the activity is a
/// mirror, and the next day loaded puts it right.
/// {@endtemplate}
class LiveActivity {
  /// {@macro live_activity}
  LiveActivity({
    required this.apiBaseUrl,
    MethodChannel? channel,
    bool? supported,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _supported = supported ?? _onIos;

  static bool get _onIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The channel `AppDelegate` answers on.
  static const channelName = 'lunna/live_activity';

  /// Where the buttons post, which the Swift side keeps for when the app
  /// is not running.
  final String apiBaseUrl;

  final MethodChannel _channel;
  final bool _supported;

  final _opened = StreamController<String>.broadcast();
  final _changed = StreamController<void>.broadcast();
  bool _listening = false;

  /// What was last sent, so a day loaded again with the same block sends
  /// nothing.
  Map<String, Object?>? _sent;
  bool _synced = false;

  /// Cards the activity was tapped open on, by id.
  Stream<String> get opened {
    _listen();
    return _opened.stream;
  }

  /// Each time a button on the activity changed the day.
  Stream<void> get changes {
    _listen();
    return _changed.stream;
  }

  /// The card a tap on the activity launched the app on, if one did.
  Future<String?> launchCard() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('launchCard');
    } on Object catch (error) {
      log('launch card failed', name: 'live_activity', error: error);
      return null;
    }
  }

  /// Shows the block running in [cards], or ends the activity when nothing
  /// runs (or nobody is signed in: pass nothing).
  Future<void> sync([List<TimelineEvent> cards = const []]) async {
    if (!_supported) return;

    final block = blockOf(cards);
    if (_synced && mapEquals(block, _sent)) return;

    try {
      await _channel.invokeMethod<void>('sync', {
        'apiBaseUrl': apiBaseUrl,
        'block': block,
      });
      _sent = block;
      _synced = true;
    } on Object catch (error) {
      log('sync failed', name: 'live_activity', error: error);
    }
  }

  void _listen() {
    if (_listening || !_supported) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'open':
          final id = call.arguments;
          if (id is String) _opened.add(id);
        case 'changed':
          // The activity redrew itself from the answer; what it sent is no
          // longer what it shows, so the next day loaded is sent again.
          _synced = false;
          _changed.add(null);
      }
    });
  }

  /// Stops listening. Only tests need this.
  Future<void> dispose() async {
    await _opened.close();
    await _changed.close();
  }
}

/// The block the activity shows for [cards], or null when nothing runs.
///
/// Running is Agora's begun task or its fixed block, paused or in overtime
/// included; never a task waiting to be begun. The same rule is
/// `BlockState.running(in:)` in Swift, which reads the answer to a button.
///
/// Instants go as milliseconds and lengths as seconds. `end` is the end it
/// counts down to: the end it ran past while it is late, and what it had
/// left from the pause while it is paused (the card's own end moves with
/// the clock then). `work` is its length without its pauses, which is what
/// its progress line is measured against.
@visibleForTesting
Map<String, Object?>? blockOf(List<TimelineEvent> cards) {
  final card = cards
      .where(
        (card) =>
            card.section == TimelineSection.agora &&
            card.managed &&
            !card.awaitingStart &&
            (!card.isTask || card.started),
      )
      .firstOrNull;
  if (card == null) return null;

  final pausedAt = card.pausedAt;
  final end = switch (pausedAt) {
    final DateTime at => at.add(Duration(seconds: card.remainingSeconds)),
    null => card.overtimeFrom ?? card.endTime,
  };

  return {
    'id': card.id,
    'kind': card.kind.wire,
    'title': card.title,
    'delivery': card.artifactTitle,
    'start': card.startTime.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'work': card.workMinutes * 60,
    'pausedLeft': pausedAt == null ? null : card.remainingSeconds,
  };
}
