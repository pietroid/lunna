import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';
import 'package:intl/intl.dart';

/// {@template chat_bubble}
/// The user's message: a balloon with the time tucked into its last line.
///
/// Only the user gets a balloon. The agent's turn can be text today and a
/// chart or a list tomorrow, and a balloon drawn around that would be a box
/// around a box.
/// {@endtemplate}
class ChatBubble extends StatelessWidget {
  /// {@macro chat_bubble}
  const ChatBubble({required this.message, super.key});

  /// The message to draw.
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          decoration: const BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.chipRadius),
              topRight: Radius.circular(AppSpacing.chipRadius),
              bottomLeft: Radius.circular(AppSpacing.chipRadius),
              bottomRight: Radius.circular(AppSpacing.s1),
            ),
          ),
          // The time sits on the text's last line when there is room and drops
          // to its own line when there is not, which is what keeps a one-word
          // message from being as wide as its timestamp.
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.s2,
            children: [
              Text(message.text, style: AppTypography.body),
              Text(
                DateFormat.Hm().format(message.createdAt),
                style: AppTypography.caption.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
