import 'package:app_ui/app_ui.dart';

/// {@template chat_composer}
/// The pill the user types into, with a send button that appears once there is
/// something to send.
///
/// Used on both the home screen and inside a chat, so the one control the app
/// is built around behaves the same in both places.
/// {@endtemplate}
class ChatComposer extends StatefulWidget {
  /// {@macro chat_composer}
  const ChatComposer({
    required this.onSubmitted,
    this.hintText,
    this.autofocus = false,
    super.key,
  });

  /// Called with the trimmed text when the user sends.
  final ValueChanged<String> onSubmitted;

  /// Text shown while the field is empty.
  final String? hintText;

  /// Whether the field takes focus as soon as it is shown.
  final bool autofocus;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    widget.onSubmitted(text);
    // Keep focus so a follow-up message does not cost another tap, and so the
    // keyboard does not close and reopen between two messages.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final canSend = value.text.trim().isNotEmpty;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: widget.hintText,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
            // The button takes its space only once it is usable, so an empty
            // composer is the plain pill the home screen is designed around.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: canSend
                  ? Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s2),
                      child: _SendButton(onPressed: _submit),
                    )
                  : const SizedBox(height: AppSpacing.fieldHeight),
            ),
          ],
        );
      },
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.fieldHeight,
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Center(
            child: AppIcon(
              iconData: AppIcons.send,
              size: AppSpacing.s5,
              color: AppColors.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
