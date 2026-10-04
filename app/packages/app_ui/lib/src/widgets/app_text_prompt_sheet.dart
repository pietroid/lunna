import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_text_prompt_sheet}
/// The sheet the orb opens everywhere except Tempo: one line, one send.
///
/// What it starts is a conversation, so it asks for nothing but the sentence:
/// whether the thing has an hour, and which one, is the model's to work out
/// with the user. Tempo's sheet is the other half of that trade, where the
/// user answers those questions up front and no model runs at all.
/// {@endtemplate}
class AppTextPromptSheet extends StatefulWidget {
  /// {@macro app_text_prompt_sheet}
  const AppTextPromptSheet({super.key});

  /// The ways the sheet asks what the user wants.
  static const hints = <String>[
    'O que posso ajudar?',
    'Em que posso ajudar?',
    'O que está na sua cabeça?',
    'Me conta o que precisa.',
    'Pode falar.',
  ];

  /// Opens the sheet and resolves with the trimmed text, or null if it was
  /// dismissed without sending.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => const AppTextPromptSheet(),
    );
  }

  @override
  State<AppTextPromptSheet> createState() => _AppTextPromptSheetState();
}

class _AppTextPromptSheetState extends State<AppTextPromptSheet> {
  final _controller = TextEditingController();
  late final String _hint = AppTextPromptSheet
      .hints[math.Random().nextInt(AppTextPromptSheet.hints.length)];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet sits on the keyboard rather than under it, so the field is
      // still visible the moment it takes focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s2,
              AppSpacing.s3,
              AppSpacing.s2,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _submit(),
                        cursorColor: AppColors.ink,
                        cursorWidth: 1.5,
                        cursorRadius: const Radius.circular(AppSpacing.s1),
                        style: AppTypography.body,
                        decoration: InputDecoration(
                          hintText: _hint,
                          hintStyle: AppTypography.body.copyWith(
                            color: AppColors.ink3,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s4,
                          ),
                        ),
                      ),
                    ),
                    _Send(
                      enabled: value.text.trim().isNotEmpty,
                      onPressed: _submit,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The send: a bare icon that lights up once there is something to send.
class _Send extends StatelessWidget {
  const _Send({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.tapTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.35,
              duration: const Duration(milliseconds: 160),
              child: const AppIcon(
                iconData: AppIcons.send,
                size: AppSpacing.s5,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
