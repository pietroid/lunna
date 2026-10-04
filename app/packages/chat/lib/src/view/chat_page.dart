import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/chat_bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// {@template chat_page}
/// One conversation.
///
/// Reached two ways: opening a thread from the home list, which loads it by
/// slug, or typing the first message on the home screen, which arrives as
/// [initialMessage] and creates the thread here so the send and its loading
/// state happen on the screen that shows them.
/// {@endtemplate}
class ChatPage extends StatelessWidget {
  /// {@macro chat_page}
  const ChatPage({this.slug, this.initialMessage, super.key});

  /// The thread to open. Null when the user is starting a new one.
  final String? slug;

  /// The message that started a new thread, sent as soon as the page opens.
  final String? initialMessage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = ChatBloc(
          chatRepository: context.read<ChatRepository>(),
        );

        if (initialMessage != null) {
          bloc.add(ChatMessageSent(initialMessage!));
        } else if (slug != null) {
          bloc.add(ChatThreadRequested(slug!));
        }

        return bloc;
      },
      child: const _ChatView(),
    );
  }
}

/// {@template chat_conversation}
/// The messages and the composer, without a page around them.
///
/// The chat screen draws it under its app bar, and the detail screen of a
/// block draws it under the block's header when the user wants to talk about
/// it. It reads the [ChatBloc] above it and nothing else.
/// {@endtemplate}
class ChatConversation extends StatelessWidget {
  /// {@macro chat_conversation}
  const ChatConversation({this.emptyText, super.key});

  /// What the conversation says before anything has been said in it.
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      child: Column(
        children: [
          Expanded(child: _Messages(emptyText: emptyText)),
          const _Composer(),
        ],
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (previous, current) => previous.title != current.title,
          builder: (context, state) => Text(
            state.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (previous, current) => previous.solved != current.solved,
            builder: (context, state) => state.solved
                ? const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.s4),
                    child: AppBadge(
                      text: 'Feito',
                      color: AppColors.success,
                      iconData: AppIconData.phosphor(Icons.check),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: const ChatConversation(),
          ),
        ),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({this.emptyText});

  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state.status == ChatStatus.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s4,
            ),
            child: AgentTyping(),
          );
        }

        final typingCount = state.isAwaiting ? 1 : 0;

        if (emptyText != null && state.messages.isEmpty && typingCount == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s6),
              child: Text(
                emptyText!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink3),
              ),
            ),
          );
        }
        final actionsEnabled = !state.isAwaitingAction;

        // Reversed so the list sits at the newest message without measuring
        // anything, and so new messages push up from the composer rather than
        // needing a scroll animation to be seen.
        return ListView.separated(
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s5,
          ),
          itemCount: state.messages.length + typingCount,
          // Turns need more air between them than lines do inside one, so the
          // separator is a step above the gap the renderer uses for children.
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s6),
          itemBuilder: (context, index) {
            if (index < typingCount) return const AgentTyping();

            final position = state.messages.length - 1 - index + typingCount;
            final message = state.messages[position];

            // Only the last turn can still be acted on. A button further up
            // the thread belongs to a decision already taken, and tapping it
            // would replay a moment the conversation has moved past.
            final isLatest = position == state.messages.length - 1;

            return message.isUser
                ? ChatBubble(message: message)
                : AgentMessage(
                    message: message,
                    enabled: actionsEnabled && isLatest,
                    onAction: (action) => _handleAction(context, action),
                  );
          },
        );
      },
    );
  }

  void _handleAction(BuildContext context, Map<String, dynamic> action) {
    final type = action['type'] as String?;

    if (type == 'openUrl') {
      final url = action['url'] as String?;
      if (url != null && url.isNotEmpty) {
        unawaited(_launchUrl(url));
      }
      return;
    }

    context.read<ChatBloc>().add(ChatActionFired(action));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: ChatComposer(
        hintText: 'Escreva uma mensagem',
        onSubmitted: (text) =>
            context.read<ChatBloc>().add(ChatMessageSent(text)),
      ),
    );
  }
}

/// Helper to silence the "unawaited future" lint for fire-and-forget calls.
void unawaited(Future<void> future) {}
