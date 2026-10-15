import 'package:agent/src/view/agent_sheet.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template ask_bar}
/// Where a conversation with the agent starts: a pill beside the +.
///
/// It only looks like a field. Tapping it opens the sheet, where the real
/// field is, so the keyboard never comes up over the day. The microphone at
/// its end is a target of its own: it opens the sheet already recording.
/// {@endtemplate}
class AskBar extends StatelessWidget {
  /// {@macro ask_bar}
  const AskBar({this.day, super.key});

  /// The day Tempo is showing, which the conversation is about.
  final DateTime? Function()? day;

  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.agentAsk(AppBrand.id),
      child: GestureDetector(
        onTap: () => showAgentSheet(context, day: day?.call()),
        child: Container(
          height: height,
          padding: const EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            children: [
              const AppIcon(iconData: AppIcons.agent, size: 22),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  context.l10n.agentAsk(AppBrand.id),
                  style: AppTypography.body.copyWith(color: AppColors.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.agentVoiceStart,
                child: GestureDetector(
                  onTap: () => showAgentSheet(
                    context,
                    day: day?.call(),
                    listen: true,
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accentWash,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AppIcon(
                        iconData: AppIcons.microphone,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
