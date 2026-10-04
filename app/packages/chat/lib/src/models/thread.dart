import 'package:chat/src/models/chat_message.dart';
import 'package:equatable/equatable.dart';

/// {@template thread}
/// A conversation, with every message it holds.
/// {@endtemplate}
class Thread extends Equatable {
  /// {@macro thread}
  const Thread({
    required this.slug,
    required this.title,
    required this.messages,
    required this.solved,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [Thread] from the API's JSON.
  factory Thread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? <dynamic>[];

    return Thread(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      messages: rawMessages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      solved: json['solved'] as bool? ?? false,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// The folder name on disk, and the id the API addresses it by.
  final String slug;

  /// A one-line name, taken from the thread's first message.
  final String title;

  /// Every message, oldest first.
  final List<ChatMessage> messages;

  /// Whether the user has marked this thread closed.
  final bool solved;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    slug,
    title,
    messages,
    solved,
    createdAt,
    updatedAt,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}
