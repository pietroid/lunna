import 'package:agent/src/agent_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template failure_note}
/// What went wrong with a turn, said for what it was: the model down, an
/// empty answer, a refusal in the server's words, a day that moved on, no
/// connection, or ours to fix. Then the way out, Tentar de novo, and under
/// Detalhes the code of the turn's trace, for whoever looks into it.
/// {@endtemplate}
class FailureNote extends StatefulWidget {
  /// {@macro failure_note}
  const FailureNote({required this.failure, required this.onRetry, super.key});

  final AgentFailure failure;

  final VoidCallback onRetry;

  @override
  State<FailureNote> createState() => _FailureNoteState();
}

class _FailureNoteState extends State<FailureNote> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = widget.failure;
    final text = agentFailureText(l10n, failure);
    final trace = failure.traceId;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: AppIcon(
                  iconData: AppIcons.warning,
                  size: 16,
                  color: AppColors.dangerInk,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body,
                ),
              ),
            ],
          ),
          if (_details && trace != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Padding(
              padding: const EdgeInsets.only(left: 16 + AppSpacing.s2),
              child: SelectableText(
                l10n.agentTrace(trace),
                style: AppTypography.label,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              if (failure.kind != AgentFailureKind.refused)
                AppButton.text(
                  text: l10n.agentRetry,
                  color: AppColors.ink,
                  onPressed: widget.onRetry,
                ),
              const Spacer(),
              if (trace != null && !_details)
                AppButton.text(
                  text: l10n.agentDetails,
                  color: AppColors.ink3,
                  onPressed: () => setState(() => _details = true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What [failure] says to the person: a refusal in the server's own words,
/// every other kind in its own line.
String agentFailureText(AppLocalizations l10n, AgentFailure failure) =>
    switch (failure.kind) {
      AgentFailureKind.refused => failure.message ?? l10n.agentFailure,
      AgentFailureKind.modelDown => l10n.agentFailureModelDown,
      AgentFailureKind.modelEmpty => l10n.agentFailureModelEmpty,
      AgentFailureKind.drift => l10n.agentFailureDrift,
      AgentFailureKind.offline => l10n.agentFailureOffline,
      AgentFailureKind.bug => l10n.agentFailureBug,
    };
