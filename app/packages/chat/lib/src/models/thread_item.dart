import 'package:equatable/equatable.dart';

/// {@template thread_item}
/// A thread in a plain list, with no claim about when it happens.
///
/// What the concluded items are drawn from. A timeline card insists on an
/// hour because everything on the timeline has one; a thread that has been
/// closed, or never scheduled, still exists and still needs a row.
/// {@endtemplate}
class ThreadItem extends Equatable {
  /// {@macro thread_item}
  const ThreadItem({
    required this.slug,
    required this.title,
    required this.preview,
    required this.messageCount,
    required this.solved,
    required this.createdAt,
    required this.updatedAt,
    this.startTime,
    this.endTime,
    this.durationMinutes,
  });

  /// Creates a [ThreadItem] from the API's JSON.
  factory ThreadItem.fromJson(Map<String, dynamic> json) {
    return ThreadItem(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      solved: json['solved'] as bool? ?? false,
      startTime: _optionalDate(json['startTime']),
      endTime: _optionalDate(json['endTime']),
      durationMinutes: json['durationMinutes'] as int?,
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }

  /// The folder name on disk, and the id the API addresses it by.
  final String slug;

  /// A one-line name, taken from the thread's first message.
  final String title;

  /// The last message's text, on one line.
  final String preview;

  /// How many messages the thread holds.
  final int messageCount;

  /// Whether the thread is closed.
  final bool solved;

  /// When it happened, if it was ever given an hour.
  final DateTime? startTime;

  /// When it ended.
  final DateTime? endTime;

  /// How long it took.
  final int? durationMinutes;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    slug,
    title,
    preview,
    messageCount,
    solved,
    startTime,
    endTime,
    durationMinutes,
    createdAt,
    updatedAt,
  ];
}

DateTime _requiredDate(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}

/// A date the API may simply not have, which is different from one it got
/// wrong: a thread that was never scheduled has no start.
DateTime? _optionalDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
