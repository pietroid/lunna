import 'dart:async';

import 'package:agent/src/models.dart';
import 'package:agent/src/suggestion_cubit.dart';
import 'package:agent/src/view/agent_sheet.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template suggestion_card}
/// The agent's one unasked-for offer, drawn at the top of Plano as a small
/// card in the agent's wash: its mark, a title, one line of description and
/// three actions.
///
/// - **Aceitar** applies the plan, with a spinner in its place while the
///   changes are made; the card goes when it is done.
/// - **Agora não** puts the suggestion away until the next one is due.
/// - **Detalhes** opens the conversation on the suggestion's prepared
///   surface (preview, plan, choices), where the person can talk, change
///   it or accept it.
///
/// A suggestion with no plan (a question, the welcome) has Detalhes only.
/// {@endtemplate}
class SuggestionCard extends StatelessWidget {
  /// {@macro suggestion_card}
  const SuggestionCard({this.accepting = false, super.key});

  /// Draws the spinner from the start; for previews and tests.
  @visibleForTesting
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final suggestion = context.watch<SuggestionCubit>().state;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: suggestion == null
          ? const SizedBox(width: double.infinity)
          : _Offer(suggestion: suggestion, accepting: accepting),
    );
  }
}

/// The title and the description of [text]: the first sentence, and what
/// follows it (empty when it is one sentence).
(String, String) suggestionWords(String text) {
  final trimmed = text.trim();
  final end = trimmed.indexOf(RegExp(r'[.!?](\s|$)'));
  if (end < 0 || end == trimmed.length - 1) {
    return (trimmed.replaceFirst(RegExp(r'[.!]$'), ''), '');
  }

  return (trimmed.substring(0, end), trimmed.substring(end + 1).trim());
}

class _Offer extends StatefulWidget {
  const _Offer({required this.suggestion, required this.accepting});

  final AgentSuggestion suggestion;
  final bool accepting;

  @override
  State<_Offer> createState() => _OfferState();
}

class _OfferState extends State<_Offer> {
  late bool _accepting = widget.accepting;

  AgentPlan? get _plan => widget.suggestion.welcome
      ? null
      : widget.suggestion.opening?.plan ?? widget.suggestion.action?.plan;

  Future<void> _accept() async {
    final plan = _plan;
    if (plan == null || _accepting) return;
    final cubit = context.read<SuggestionCubit>();
    setState(() => _accepting = true);
    final done = await applyAgentPlan(context, plan);
    if (done) {
      cubit.clear();
    } else if (mounted) {
      setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestion = widget.suggestion;
    final (title, description) = suggestion.welcome
        ? (l10n.agentWelcomeQuestion, '')
        : suggestionWords(suggestion.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s1),
                  child: AppIcon(
                    iconData: AppIcons.agent,
                    size: AppSpacing.s4,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                if (_plan != null)
                  _accepting
                      ? const _Spinner()
                      : AppButton.icon(
                          icon: const AppIcon(iconData: AppIcons.check),
                          text: l10n.agentSuggestionAccept,
                          onPressed: () => unawaited(_accept()),
                        ),
                if (_plan != null) const SizedBox(width: AppSpacing.s2),
                AppPillButton(
                  label: l10n.agentSuggestionDetails,
                  iconData: AppIcons.arrowRight,
                  onPressed: () => unawaited(
                    showAgentSheet(context, suggestion: suggestion),
                  ),
                ),
                const Spacer(),
                if (!_accepting)
                  // The pill's own padding is moved out so its label ends on
                  // the card's inner edge, like the text above it.
                  Transform.translate(
                    offset: const Offset(AppSpacing.s3, 0),
                    child: AppPillButton(
                      label: l10n.agentSuggestionDismiss,
                      iconData: AppIcons.close,
                      onPressed: () =>
                          unawaited(context.read<SuggestionCubit>().dismiss()),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where Aceitar was, while the changes are made.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.s4,
      vertical: AppSpacing.s1,
    ),
    child: SizedBox(
      width: AppSpacing.s4,
      height: AppSpacing.s4,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.accent,
      ),
    ),
  );
}
