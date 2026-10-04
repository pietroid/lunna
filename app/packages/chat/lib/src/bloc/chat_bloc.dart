import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// {@template chat_bloc}
/// Drives one chat screen.
///
/// A message is shown the moment it is sent, before the server has seen it, so
/// the screen never looks like it dropped what the user typed. The agent's
/// answer is what the typing indicator waits for.
///
/// Actions are not interpreted here. `dismiss` and `openUrl` are the only two
/// the app can finish on its own; everything else is posted to the server as
/// it arrived. An earlier version guessed at tool actions and, when it could
/// not find an id, sent a fabricated message reading "Please run
/// calendar_create_event with {...}" into the conversation. That is exactly
/// the class of bug that goes unnoticed until it is in a screenshot.
/// {@endtemplate}
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  /// {@macro chat_bloc}
  ChatBloc({required this.chatRepository, this.threadStarter})
    : super(const ChatState()) {
    on<ChatThreadRequested>(_onThreadRequested);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatActionFired>(_onActionFired);
  }

  /// Repository used to read and write threads.
  final ChatRepository chatRepository;

  /// Gives the slug of the thread to write into, when there is none yet.
  ///
  /// Set by a screen whose conversation belongs to something else, like a
  /// block of time: the thread is only created, and linked to it, when the
  /// first message is sent. Without it a first message starts a thread of
  /// its own.
  final Future<String> Function()? threadStarter;

  Future<void> _onThreadRequested(
    ChatThreadRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(status: ChatStatus.loading, slug: event.slug));

    try {
      emit(_loaded(await chatRepository.fetchThread(event.slug)));
    } on Exception catch (error, stackTrace) {
      _logFailure('fetchThread', error, stackTrace);
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          errorMessage: 'Could not open this thread.',
        ),
      );
    }
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final pending = ChatMessage.pending(text);
    final slug = state.slug;

    emit(
      state.copyWith(
        status: ChatStatus.awaitingReply,
        title: state.title.isEmpty ? text : state.title,
        messages: [...state.messages, pending],
      ),
    );

    try {
      final starter = threadStarter;
      final thread = slug != null
          ? await chatRepository.sendMessage(slug, text)
          : starter != null
          ? await chatRepository.sendMessage(await starter(), text)
          : await chatRepository.createThread(text);

      emit(_loaded(thread));
    } on Exception catch (error, stackTrace) {
      _logFailure('sendMessage', error, stackTrace);

      // Drop the optimistic copy: leaving it on screen under an error would
      // claim the message was sent when it was not.
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          messages: state.messages
              .where((message) => message.id != pending.id)
              .toList(),
          errorMessage: 'Could not send that message.',
        ),
      );
    }
  }

  Future<void> _onActionFired(
    ChatActionFired event,
    Emitter<ChatState> emit,
  ) async {
    final action = event.action;
    final type = action['type'] as String?;
    final slug = state.slug;

    log(
      '[ChatBloc] action fired',
      name: 'chat_bloc',
      error: {'type': type, 'slug': slug, 'action': action},
    );

    // Handled entirely on this side: nothing to ask the server about.
    if (type == 'dismiss' || type == 'openUrl') return;

    if (slug == null) {
      log(
        '[ChatBloc] action dropped: the thread has no slug yet',
        name: 'chat_bloc',
        error: {'type': type},
      );
      return;
    }

    // Every action is disabled at once, so a double tap cannot resolve the
    // same pending call twice while the first request is still open.
    emit(state.copyWith(status: ChatStatus.awaitingAction));

    try {
      emit(_loaded(await chatRepository.runAction(slug: slug, action: action)));
    } on Exception catch (error, stackTrace) {
      _logFailure('runAction', error, stackTrace);
      emit(
        state.copyWith(
          // Back to ready rather than failure, so the buttons come alive again
          // and the user can retry the action they meant.
          status: ChatStatus.ready,
          errorMessage: 'That did not go through. Try again.',
        ),
      );
    }
  }

  void _logFailure(String operation, Object error, StackTrace stackTrace) {
    log(
      '[ChatBloc] $operation failed',
      name: 'chat_bloc',
      error: error,
      stackTrace: stackTrace,
    );
  }

  ChatState _loaded(Thread thread) {
    final trace = thread.messages.last.metadata?.traceId;
    if (trace != null) {
      // Printed on every turn so a screenshot of the app is enough to find the
      // matching server and agent logs.
      log('[ChatBloc] turn $trace', name: 'chat_bloc');
    }

    return ChatState(
      status: ChatStatus.ready,
      slug: thread.slug,
      title: thread.title,
      messages: thread.messages,
      solved: thread.solved,
    );
  }
}
