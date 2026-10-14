import 'package:equatable/equatable.dart';

/// {@template placement}
/// Where something written down goes.
///
/// Three answers, and they are the three things the day knows how to hold:
/// the backlog, which has an order and no hours; a place in the queue,
/// which takes its turn; and an hour, which a task keeps while the queue
/// flows around it.
/// {@endtemplate}
class Placement extends Equatable {
  /// The end of the backlog.
  const Placement.backlog()
    : backlog = true,
      index = null,
      at = null,
      minutes = null;

  /// A place in the list of tasks, counted the way a drag counts it: from
  /// the top, what is running included.
  const Placement.queue(int this.index)
    : backlog = false,
      at = null,
      minutes = null;

  /// Anchored at an hour, and, when the room it was asked for is short,
  /// [minutes] long, so it fills that room.
  const Placement.at(DateTime this.at, {this.minutes})
    : backlog = false,
      index = null;

  /// Whether it goes to the backlog.
  final bool backlog;

  /// Its place in the list of tasks, when it takes its turn.
  final int? index;

  /// The hour it keeps, when it has one.
  final DateTime? at;

  /// The length the creation sheet opens on, when it is not the usual one.
  final int? minutes;

  @override
  List<Object?> get props => [backlog, index, at, minutes];
}

/// {@template timeline_aim}
/// Where the button at the foot of the app writes something down: wherever
/// the day on screen is looking.
///
/// The timeline sets it as it is scrolled, to the first free hour it shows,
/// or to the end of the day section at the top of the list. Null until the
/// timeline has been drawn, which is the backlog.
///
/// Read when the button is pressed rather than listened to: nothing on the
/// screen redraws because the day was scrolled.
/// {@endtemplate}
class TimelineAim {
  /// Where the next thing written down goes, when the timeline has said.
  Placement? value;
}
