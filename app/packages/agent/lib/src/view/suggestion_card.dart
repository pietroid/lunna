import 'dart:async';

import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/models.dart';
import 'package:agent/src/suggestion_cubit.dart';
import 'package:agent/src/surface.dart';
import 'package:agent/src/view/agent_preview.dart';
import 'package:agent/src/view/agent_sheet.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:agent/src/view/offer_actions.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template suggestion_card}
/// The agent's one unasked-for offer, drawn at the top of the Feed, in
/// three parts:
///
/// - a **header** in the agent's wash: its mark, "Sugestão da Lunna", the
///   ✕, and the turn's words, which are all the agent says here;
/// - the **preview** on the page's own background: what the plan would
///   make, drawn by the tabs' widgets (`GoalCard`, `ArtifactRow`, a
///   routine's block), or the answers to tap when the turn asks instead;
/// - the **actions**, in the wash again: what Aplicar makes that the
///   preview can't show, Ajustar (the conversation, opened on this turn)
///   and Aplicar.
///
/// A new person's is the welcome: fixed words and the amounts to bill,
/// and no actions, since it has no plan. The ✕ puts a suggestion away until
/// the next one is due.
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
          : _Offer(suggestion: suggestion),
    );
  }
}

/// What the welcome offers to bill, in reais; "Outro valor" follows.
const kWelcomeAmounts = [3000, 5000, 8000];

class _Offer extends StatelessWidget {
  const _Offer({required this.suggestion});

  final AgentSuggestion suggestion;

  /// The conversation, starting from the turn the card draws.
  void _talk(BuildContext context) => unawaited(
    showAgentSheet(context, suggestion: suggestion),
  );

  /// The conversation, opened on [said] as the person's first message.
  void _say(BuildContext context, String said) {
    final agent = context.read<AgentCubit>();
    unawaited(showAgentSheet(context, suggestion: suggestion));
    unawaited(agent.send(said));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final opening = suggestion.opening;
    final preview = opening?.blocks.whereType<PreviewBlock>().firstOrNull;
    final plan = opening?.plan;
    final options = opening?.options ?? const <QuickReply>[];

    final body = suggestion.welcome
        ? _Answers(
            labels: [
              for (final amount in kWelcomeAmounts)
                l10n.agentWelcomeAmount(amount),
              l10n.agentWelcomeOther,
            ],
            onPick: (i) => i < kWelcomeAmounts.length
                ? _say(context, l10n.agentWelcomeSay(kWelcomeAmounts[i]))
                : _talk(context),
          )
        : preview != null
        ? AgentPreview(block: preview)
        : options.isEmpty
        ? null
        : _Answers(
            labels: [for (final it in options) it.label],
            onPick: (i) => switch (options[i]) {
              QuickReply(:final plan?) => unawaited(
                applyAgentPlan(context, plan).then((done) {
                  if (done && context.mounted) {
                    context.read<SuggestionCubit>().clear();
                  }
                }),
              ),
              QuickReply(:final say?) => _say(context, say),
              _ => _talk(context),
            },
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            onTap: () => _talk(context),
            onDismiss: () => context.read<SuggestionCubit>().dismiss(),
            children: suggestion.welcome
                ? [
                    Text(
                      l10n.agentWelcome(AppBrand.id),
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      l10n.agentWelcomeQuestion,
                      style: AppTypography.bodyStrong,
                    ),
                  ]
                : [Text(suggestion.text, style: AppTypography.body)],
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.s4),
            body,
          ],
          if (plan != null && !suggestion.welcome) ...[
            const SizedBox(height: AppSpacing.s3),
            OfferActions(
              applies: preview?.applies,
              status: PlanStatus.pending,
              onAdjust: () => _talk(context),
              onApply: () async {
                final cubit = context.read<SuggestionCubit>();
                if (await applyAgentPlan(context, plan)) cubit.clear();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The agent's mark, its label and the ✕, over its words. A tap on it
/// opens the conversation.
class _Header extends StatelessWidget {
  const _Header({
    required this.children,
    required this.onTap,
    required this.onDismiss,
  });

  final List<Widget> children;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AgentWash(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
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
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: l10n.agentSuggestionDismiss,
                      child: AppIconButton(
                        iconData: AppIcons.close,
                        size: AppSpacing.s4,
                        color: AppColors.ink3,
                        onPressed: onDismiss,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
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

/// The answers a turn with no plan offers, on the page: the welcome's
/// amounts, or the turn's own choices.
class _Answers extends StatelessWidget {
  const _Answers({required this.labels, required this.onPick});

  final List<String> labels;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s2,
    runSpacing: AppSpacing.s2,
    children: [
      for (final (i, label) in labels.indexed)
        AppButton(
          text: label,
          variant: AppButtonVariant.secondary,
          onPressed: () => onPick(i),
        ),
    ],
  );
}
