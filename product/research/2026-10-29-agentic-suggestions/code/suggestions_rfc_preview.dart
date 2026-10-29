import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';

/// The research RFC's two pictures of one onboarding plan (a goal and two
/// deliveries): `?s=1` as the plan card draws it today, `?s=2` drawn by
/// the widgets the tabs draw once it is applied; `?s=3` the suggestion as
/// Feed would hold it, the preview first and Ajustar / Aplicar under it;
/// `?s=4` the welcome a new person finds. Nothing ships from here.
void main() => runApp(const _App());

final DateTime _now = DateTime(2026, 10, 31, 10);
final DateTime _end = DateTime(2026, 11, 30);

final String _scene = Uri.base.queryParameters['s'] ?? '1';

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.current,
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: switch (_scene) {
            '1' => _today(),
            '2' => _preview(),
            '3' => [_offer()],
            _ => [_welcome()],
          },
        ),
      ),
    ),
  );

  List<Widget> _today() => [
    PlanCard(
      plan: AgentPlan(
        id: 'p',
        changes: [
          PlanChange(
            kind: PlanChangeKind.addGoal,
            title: 'R\$ 5.000',
            minutes: 0,
            goal: PlanGoal(money: true, target: 5000, deadline: _end),
          ),
          PlanChange(
            kind: PlanChangeKind.addArtifact,
            title: 'Ensaio de gestante',
            minutes: 240,
            deadline: DateTime(2026, 11, 14),
            value: 1800,
          ),
          PlanChange(
            kind: PlanChangeKind.addArtifact,
            title: 'Álbum da Marina',
            minutes: 360,
            deadline: DateTime(2026, 11, 25),
            value: 2400,
          ),
        ],
      ),
      status: PlanStatus.pending,
      onApply: () {},
      onAdjust: () {},
    ),
  ];

  List<Widget> _preview() => [
    GoalCard(
      goal: Goal(
        id: 'g',
        kind: GoalKind.money,
        target: 5000,
        queued: 4200,
        queuedCount: 2,
        start: DateTime(2026, 10, 31),
        end: DateTime(2026, 12),
      ),
      now: _now,
    ),
    const SizedBox(height: 16),
    for (final (title, minutes, day, value) in [
      ('Ensaio de gestante', 240, 14, 1800),
      ('Álbum da Marina', 360, 25, 2400),
    ]) ...[
      ArtifactRow(
        artifact: Artifact(
          id: title,
          title: title,
          minutes: minutes,
          createdAt: _now,
          value: value,
          deadline: DateTime(2026, 11, day),
        ),
        now: _now,
      ),
      const SizedBox(height: 8),
    ],
  ];

  /// The agent's wash, its mark and its label, around [children].
  Widget _wash(List<Widget> children) => Builder(
    builder: (context) => Container(
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
              const AppIcon(iconData: AppIcons.agent, size: AppSpacing.s4),
              const SizedBox(width: AppSpacing.s2),
              Text(
                context.l10n.agentSuggestionLabel(AppBrand.id),
                style: AppTypography.caption.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          ...children,
        ],
      ),
    ),
  );

  Widget _offer() => _wash([
    Text(
      'Com essas duas entregas você chega a R\$ 4.200 dos R\$ 5.000 do mês. '
      'Quer anotar as duas?',
      style: AppTypography.body,
    ),
    const SizedBox(height: AppSpacing.s3),
    ..._preview(),
    const SizedBox(height: AppSpacing.s2),
    Row(
      children: [
        Expanded(
          child: AppButton.text(
            text: 'Ajustar',
            color: AppColors.ink,
            expand: true,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: AppButton(text: 'Aplicar', expand: true, onPressed: () {}),
        ),
      ],
    ),
  ]);

  /// No Work Quality on screen: the levels are the server's, and the
  /// welcome only asks the first one's question.
  Widget _welcome() => _wash([
    Text(
      'Oi! Eu sou a Lunna. Vou te ajudar a montar o seu mês, um passo de '
      'cada vez. Começando pelo objetivo:',
      style: AppTypography.body,
    ),
    const SizedBox(height: AppSpacing.s3),
    Text('Quanto você quer faturar este mês?', style: AppTypography.body),
    const SizedBox(height: AppSpacing.s2),
    Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final it in ['R\$ 3.000', 'R\$ 5.000', 'R\$ 8.000', 'Outro'])
          AppButton(
            text: it,
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
      ],
    ),
  ]);
}
