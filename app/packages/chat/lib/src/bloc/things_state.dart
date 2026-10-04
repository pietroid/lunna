part of 'things_bloc.dart';

/// The status of Coisas.
enum ThingsStatus {
  /// Nothing has been requested yet.
  initial,

  /// The list is being fetched.
  loading,

  /// The list is available.
  success,

  /// The last thing tried did not happen.
  failure,
}

/// {@template things_state}
/// The state of Coisas.
/// {@endtemplate}
final class ThingsState extends Equatable {
  /// {@macro things_state}
  const ThingsState({
    this.status = ThingsStatus.initial,
    this.things = const [],
    this.failure,
    this.scheduled,
    this.scheduledCount = 0,
  });

  /// The status of the list.
  final ThingsStatus status;

  /// Every thing, top first.
  final List<Thing> things;

  /// Why the last thing tried did not happen, in the server's words.
  final String? failure;

  /// The thing most recently moved onto the timeline.
  final Thing? scheduled;

  /// How many things have been moved onto the timeline, so moving the same
  /// one twice still reads as two moves.
  final int scheduledCount;

  /// Whether the first load is still in flight.
  bool get isInitialLoad => status == ThingsStatus.loading && things.isEmpty;

  /// Returns a copy with the given fields replaced.
  ThingsState copyWith({
    ThingsStatus? status,
    List<Thing>? things,
    String? failure,
    Thing? scheduled,
    int? scheduledCount,
    bool clearFailure = false,
  }) {
    return ThingsState(
      status: status ?? this.status,
      things: things ?? this.things,
      failure: clearFailure ? null : failure ?? this.failure,
      scheduled: scheduled ?? this.scheduled,
      scheduledCount: scheduledCount ?? this.scheduledCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    things,
    failure,
    scheduled,
    scheduledCount,
  ];
}
