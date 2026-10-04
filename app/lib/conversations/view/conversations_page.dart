import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:go_router/go_router.dart';

/// {@template conversations_page}
/// Conversas: every conversation, cut into the days they were last replied
/// to.
///
/// The orb on this tab starts a conversation, and this is where the ones
/// already started stay. Tapping a row opens the thread where it was left.
/// {@endtemplate}
class ConversationsPage extends StatelessWidget {
  /// {@macro conversations_page}
  const ConversationsPage({this.reloadToken = 0, super.key});

  /// Bumped by the shell when a conversation was started from the orb.
  final int reloadToken;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.s5,
                    bottom: AppSpacing.s2,
                  ),
                  child: Text('Conversas', style: AppTypography.headline),
                ),
                Expanded(
                  child: ConversationsSection(
                    reloadToken: reloadToken,
                    onThreadTap: (slug) => context.push<void>('/chat/$slug'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
