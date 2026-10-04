part of 'chat_bloc.dart';

/// The status of a chat.
enum ChatStatus {
  /// Nothing has been requested yet.
  initial,

  /// An existing thread is being fetched.
  loading,

  /// The thread is on screen and idle.
  ready,

  /// The user's message is on screen and the agent has not answered yet.
  awaitingReply,

  /// An action is in flight and every button is disabled.
  awaitingAction,

  /// Something failed.
  failure,
}

/// {@template chat_state}
/// The state of one chat screen.
/// {@endtemplate}
final class ChatState extends Equatable {
  /// {@macro chat_state}
  const ChatState({
    this.status = ChatStatus.initial,
    this.slug,
    this.title = '',
    this.messages = const [],
    this.solved = false,
    this.errorMessage,
  });

  /// The status of the chat.
  final ChatStatus status;

  /// The thread's id, once the server has created it.
  ///
  /// Null while the first message of a brand new thread is still in flight.
  final String? slug;

  /// The thread's one-line name.
  final String title;

  /// Every message on screen, oldest first, including one the server has not
  /// acknowledged yet.
  final List<ChatMessage> messages;

  /// Whether the thread has been marked closed.
  final bool solved;

  /// What went wrong, when [status] is [ChatStatus.failure].
  final String? errorMessage;

  /// Whether to show the typing indicator at the end of the list.
  bool get isAwaitingReply => status == ChatStatus.awaitingReply;

  /// Whether an action is in flight and the buttons are disabled.
  bool get isAwaitingAction => status == ChatStatus.awaitingAction;

  /// Whether any agent response is being waited for.
  bool get isAwaiting => isAwaitingReply || isAwaitingAction;

  /// Returns a copy with the given fields replaced.
  ///
  /// [errorMessage] clears unless it is passed, so a retry does not leave a
  /// stale snackbar behind it.
  ChatState copyWith({
    ChatStatus? status,
    String? slug,
    String? title,
    List<ChatMessage>? messages,
    bool? solved,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      solved: solved ?? this.solved,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    slug,
    title,
    messages,
    solved,
    errorMessage,
  ];
}
