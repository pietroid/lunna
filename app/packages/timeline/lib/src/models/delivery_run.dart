import 'package:timeline/src/models/timeline_event.dart';

/// [cards] cut into runs: each run is the tasks of one delivery that follow
/// each other, and every other card is a run of its own.
///
/// Only cards next to each other join, so the runs keep the order of the
/// day, and [joins] can refuse any two that are: the calendar refuses two
/// with drawn room between them, or under two headings.
List<List<TimelineEvent>> deliveryRuns(
  Iterable<TimelineEvent> cards, {
  bool Function(TimelineEvent before, TimelineEvent after)? joins,
}) {
  final runs = <List<TimelineEvent>>[];

  for (final card in cards) {
    final run = runs.lastOrNull;
    final last = run?.last;
    if (run != null &&
        last != null &&
        sameDelivery(last, card) &&
        (joins?.call(last, card) ?? true)) {
      run.add(card);
    } else {
      runs.add([card]);
    }
  }

  return runs;
}

/// Whether [a] and [b] are both tasks of the same delivery.
bool sameDelivery(TimelineEvent a, TimelineEvent b) =>
    a.isTask &&
    b.isTask &&
    a.artifactId != null &&
    a.artifactId == b.artifactId;
