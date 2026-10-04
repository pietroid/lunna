import 'package:equatable/equatable.dart';

/// {@template thing}
/// One thing to do that has no hour yet.
///
/// Coisas is the timeline with the clock taken out: an order and nothing
/// else. What is at the top is what the user means to get to first, and the
/// one way a thing gets an hour is being moved onto the timeline, where it
/// stops being a thing and becomes a block.
/// {@endtemplate}
class Thing extends Equatable {
  /// {@macro thing}
  const Thing({
    required this.id,
    required this.title,
    required this.durationMinutes,
  });

  /// Creates a [Thing] from the API's JSON.
  factory Thing.fromJson(Map<String, dynamic> json) {
    return Thing(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 30,
    );
  }

  /// The server's id for it.
  final String id;

  /// What it is.
  final String title;

  /// How long it will take once it is on the day.
  final int durationMinutes;

  @override
  List<Object?> get props => [id, title, durationMinutes];
}
