part of 'chat_bloc.dart';

/// {@template chat_event}
/// Base class for events handled by [ChatBloc].
/// {@endtemplate}
sealed class ChatEvent extends Equatable {
  /// {@macro chat_event}
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Loads an existing thread the user opened from the home screen.
final class ChatThreadRequested extends ChatEvent {
  /// {@macro chat_event}
  const ChatThreadRequested(this.slug);

  /// The thread to load.
  final String slug;

  @override
  List<Object?> get props => [slug];
}

/// Sends a message.
///
/// Starts a new thread when the chat has no slug yet, which is the case when
/// the user has just typed the first message on the home screen.
final class ChatMessageSent extends ChatEvent {
  /// {@macro chat_event}
  const ChatMessageSent(this.text);

  /// What the user typed.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// Carries an action from a rendered component straight to the server.
final class ChatActionFired extends ChatEvent {
  /// {@macro chat_event}
  const ChatActionFired(this.action);

  /// The action object, exactly as the component carried it.
  final Map<String, dynamic> action;

  @override
  List<Object?> get props => [action];
}
