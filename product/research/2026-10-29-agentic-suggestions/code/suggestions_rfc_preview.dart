import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';

/// The research RFC's two pictures of one onboarding plan (a goal and two
/// deliveries): `?s=1` as the plan card draws it today, `?s=2` drawn by
/// the widgets the tabs draw once it is applied. Nothing ships from here.
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
          children: _scene == '1' ? _today() : _preview(),
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
}
