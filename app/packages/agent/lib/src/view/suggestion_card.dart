import 'package:agent/src/suggestion_cubit.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template suggestion_card}
/// The agent's one unasked-for offer, drawn on Tempo above the list.
///
/// It is quieter than any card: a wash of the accent, the agent's mark, a
/// sentence and two buttons. Encaixar applies the plan the server already
/// made; Agora não puts suggestions away for a day.
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
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                0,
                AppSpacing.s6,
                AppSpacing.s3,
              ),
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: BoxDecoration(
                color: AppColors.accentWash,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
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
                        context.l10n.agentSuggestionLabel(AppBrand.id),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(suggestion.text, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      AppButton(
                        text: context.l10n.agentSuggestionAccept,
                        onPressed: () async {
                          final cubit = context.read<SuggestionCubit>();
                          if (await applyAgentPlan(context, suggestion.plan)) {
                            cubit.clear();
                          }
                        },
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      AppButton.text(
                        text: context.l10n.agentSuggestionDismiss,
                        color: AppColors.ink2,
                        onPressed: () =>
                            context.read<SuggestionCubit>().dismiss(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
