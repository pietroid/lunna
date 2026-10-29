import 'dart:async';

import 'package:agent/src/models.dart';
import 'package:agent/src/suggestion_cubit.dart';
import 'package:agent/src/view/agent_sheet.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template suggestion_card}
/// The agent's one unasked-for offer, drawn on Tempo above the list.
///
/// It is quieter than any card: a wash of the accent, the agent's mark and
/// what it is about (the goal, a delivery, the routine), a sentence, and
/// at most two buttons. The suggestion's own action, when it has one, is
/// made from here; Conversar opens the conversation on the suggestion,
/// plan and all. The ✕ puts suggestions away for a day.
/// {@endtemplate}
class SuggestionCard extends StatelessWidget {
  /// {@macro suggestion_card}
  const SuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final suggestion = context.watch<SuggestionCubit>().state;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: suggestion == null
          ? const SizedBox(width: double.infinity)
          : _Card(suggestion: suggestion),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.suggestion});

  final AgentSuggestion suggestion;

  /// The conversation, starting from what the card said.
  void _talk(BuildContext context) => unawaited(
    showAgentSheet(
      context,
      opening: suggestion.opening ?? AgentReply(text: suggestion.text),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = suggestion.action;
    final (icon, focus) = switch (suggestion.focus) {
      SuggestionFocus.goal => (AppIcons.goal, l10n.agentSuggestionGoal),
      SuggestionFocus.delivery => (
        AppIcons.artifacts,
        l10n.agentSuggestionDelivery,
      ),
      SuggestionFocus.routine => (AppIcons.repeat, l10n.agentSuggestionRoutine),
    };
    final caption = AppTypography.caption.copyWith(color: AppColors.accent);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentWash,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // The whole card talks; only the action makes something.
          onTap: () => _talk(context),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s2,
              AppSpacing.s1,
              AppSpacing.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIcon(
                      iconData: AppIcons.agent,
                      size: AppSpacing.s4,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      l10n.agentSuggestionLabel(AppBrand.id),
                      style: caption,
                    ),
                    Text('  ·  ', style: caption),
                    AppIcon(
                      iconData: icon,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Text(focus, style: caption),
                    const Spacer(),
                    Tooltip(
                      message: l10n.agentSuggestionDismiss,
                      child: AppIconButton(
                        iconData: AppIcons.close,
                        size: AppSpacing.s4,
                        color: AppColors.ink3,
                        onPressed: () =>
                            context.read<SuggestionCubit>().dismiss(),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s3),
                  child: Text(suggestion.text, style: AppTypography.body),
                ),
                const SizedBox(height: AppSpacing.s3),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s3),
                  child: Row(
                    children: [
                      if (action != null) ...[
                        AppButton(
                          text: action.label,
                          onPressed: () async {
                            final cubit = context.read<SuggestionCubit>();
                            if (await applyAgentPlan(context, action.plan)) {
                              cubit.clear();
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.s2),
                      ],
                      AppButton.icon(
                        icon: AppIcon(
                          iconData: AppIcons.chat,
                          size: 18,
                          color: action == null
                              ? AppColors.onAccent
                              : AppColors.accent,
                        ),
                        text: l10n.agentSuggestionTalk,
                        variant: action == null
                            ? AppButtonVariant.primary
                            : AppButtonVariant.secondary,
                        onPressed: () => _talk(context),
                      ),
                    ],
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
