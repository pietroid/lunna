part of 'things_bloc.dart';

/// {@template things_event}
/// Something that happened to Coisas.
/// {@endtemplate}
sealed class ThingsEvent extends Equatable {
  /// {@macro things_event}
  const ThingsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the list.
final class ThingsRequested extends ThingsEvent {
  /// {@macro things_event}
  const ThingsRequested();
}

/// Writes a thing down at the bottom of the list.
final class ThingAdded extends ThingsEvent {
  /// {@macro things_event}
  const ThingAdded({required this.title, required this.durationMinutes});

  /// What it is.
  final String title;

  /// How long it will take once it is on the day.
  final int durationMinutes;

  @override
  List<Object?> get props => [title, durationMinutes];
}

/// Renames a thing or changes how long it will take.
final class ThingEdited extends ThingsEvent {
  /// {@macro things_event}
  const ThingEdited(this.id, {this.title, this.durationMinutes});

  /// The thing.
  final String id;

  /// The new name, when it changed.
  final String? title;

  /// The new length, when it changed.
  final int? durationMinutes;

  @override
  List<Object?> get props => [id, title, durationMinutes];
}

/// Puts a thing at [index], counted with it lifted out.
final class ThingMoved extends ThingsEvent {
  /// {@macro things_event}
  const ThingMoved({required this.id, required this.index});

  /// The thing that was dragged.
  final String id;

  /// Where it was dropped.
  final int index;

  @override
  List<Object?> get props => [id, index];
}

/// Takes a thing off the list as done.
final class ThingFinished extends ThingsEvent {
  /// {@macro things_event}
  const ThingFinished(this.id);

  /// The thing.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Takes a thing off the list for good.
final class ThingDeleted extends ThingsEvent {
  /// {@macro things_event}
  const ThingDeleted(this.id);

  /// The thing.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Moves a thing onto the timeline, into the first gap that fits it.
final class ThingScheduled extends ThingsEvent {
  /// {@macro things_event}
  const ThingScheduled(this.id);

  /// The thing.
  final String id;

  @override
  List<Object?> get props => [id];
}
