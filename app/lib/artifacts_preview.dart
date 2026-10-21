import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';

/// Draws Entregas against fixed data, one scene per `?s=<n>`:
/// 1 the tab, 2 every delivery searched, 3 the catalogue, 4 a delivery
/// picked from it, 5 a goal, 6 the catalogue as everyone first finds it,
/// empty. Nothing ships from here.
void main() => runApp(const _PreviewApp());

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

/// Wednesday, 21 October 2026, mid-morning.
final _now = DateTime(2026, 10, 21, 10, 12);

const _mapa = CatalogType(
  id: 'mapa',
  name: 'Mapa astral',
  minutes: 180,
  price: 350,
  blockMinutes: 60,
);
const _revolucao = CatalogType(
  id: 'rev',
  name: 'Revolução solar',
  minutes: 90,
  price: 280,
);
const _sinastria = CatalogType(
  id: 'sin',
  name: 'Sinastria',
  minutes: 150,
  price: 420,
  blockMinutes: 60,
);
const _retorno = CatalogType(
  id: 'ret',
  name: 'Consulta de retorno',
  minutes: 60,
  price: 180,
);
const _post = CatalogType(id: 'post', name: 'Post no Instagram', minutes: 60);
const _reels = CatalogType(
  id: 'reels',
  name: 'Reels',
  minutes: 180,
  blockMinutes: 60,
);
const _newsletter = CatalogType(id: 'news', name: 'Newsletter', minutes: 120);
const _relatorio = CatalogType(
  id: 'rel',
  name: 'Relatório anual',
  minutes: 1440,
  price: 97,
);
const _curso = CatalogType(id: 'curso', name: 'Curso gravado', minutes: 2400);

const _atendimentos = CatalogCategory(
  id: 'atend',
  name: 'Atendimentos',
  types: [_mapa, _revolucao, _sinastria, _retorno],
);
const _conteudo = CatalogCategory(
  id: 'cont',
  name: 'Conteúdo',
  types: [_post, _reels, _newsletter],
);
const _produtos = CatalogCategory(
  id: 'prod',
  name: 'Produtos',
  types: [_relatorio, _curso],
);
const List<CatalogCategory> _categories = [_atendimentos, _conteudo, _produtos];

DateTime _day(int month, int day) => DateTime(2026, month, day);

final _queue = [
  Artifact(
    id: '1',
    title: 'Mapa astral · Camila Rocha',
    category: _atendimentos,
    type: _mapa,
    minutes: 180,
    doneMinutes: 45,
    value: 350,
    deadline: _day(10, 23),
    blockMinutes: 60,
  ),
  Artifact(
    id: '2',
    title: 'Post: Mercúrio retrógrado',
    category: _conteudo,
    type: _post,
    minutes: 60,
    deadline: _day(10, 22),
  ),
  Artifact(
    id: '3',
    title: 'Reels: Lua cheia em Touro',
    category: _conteudo,
    type: _reels,
    minutes: 180,
    deadline: _day(10, 25),
    blockMinutes: 60,
  ),
  Artifact(
    id: '4',
    title: 'Revolução solar · Marina Alves',
    category: _atendimentos,
    type: _revolucao,
    minutes: 90,
    value: 280,
    deadline: _day(10, 27),
  ),
  Artifact(
    id: '5',
    title: 'Relatório anual 2027',
    category: _produtos,
    type: _relatorio,
    minutes: 1440,
    doneMinutes: 540,
    stepsDone: 3,
    steps: 8,
    deadline: _day(11, 30),
  ),
  Artifact(
    id: '6',
    title: 'Sinastria · Ana e Pedro',
    category: _atendimentos,
    type: _sinastria,
    minutes: 150,
    value: 420,
    deadline: _day(10, 29),
    blockMinutes: 60,
  ),
  Artifact(
    id: '7',
    title: 'Consulta de retorno · Júlia Mendes',
    category: _atendimentos,
    type: _retorno,
    minutes: 60,
    value: 180,
    deadline: _day(10, 30),
  ),
  Artifact(
    id: '8',
    title: 'Mapa astral · Beatriz Lima',
    category: _atendimentos,
    type: _mapa,
    minutes: 180,
    value: 350,
    deadline: _day(11, 4),
    blockMinutes: 60,
  ),
  Artifact(
    id: '9',
    title: 'Post: Vênus em Escorpião',
    category: _conteudo,
    type: _post,
    minutes: 60,
    deadline: _day(11, 3),
  ),
];

final _done = [
  Artifact(
    id: 'd1',
    title: 'Mapa astral · Renata Souza',
    category: _atendimentos,
    type: _mapa,
    minutes: 180,
    value: 350,
    doneAt: _day(10, 14),
  ),
  Artifact(
    id: 'd2',
    title: 'Mapa astral · Luiza Prado',
    category: _atendimentos,
    type: _mapa,
    minutes: 180,
    value: 350,
    doneAt: _day(10, 8),
  ),
  Artifact(
    id: 'd3',
    title: 'Mapa astral · Carla Dias',
    category: _atendimentos,
    type: _mapa,
    minutes: 180,
    value: 350,
    doneAt: _day(10, 2),
  ),
];

final _goals = [
  // Delivered R$ 4.900 so far; the queue holds R$ 1.230 due in October.
  Goal(
    id: 'g1',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 8000,
    done: 4900,
    queued: 1230,
    start: _day(10, 1),
    end: _day(11, 1),
  ),
  Goal(
    id: 'g2',
    kind: GoalKind.count,
    period: GoalPeriod.week,
    target: 3,
    done: 2,
    queued: 1,
    type: _post,
    start: _day(10, 19),
    end: _day(10, 26),
  ),
  Goal(
    id: 'g3',
    kind: GoalKind.money,
    period: GoalPeriod.month,
    target: 10000,
    queued: 350,
    start: _day(11, 1),
    end: _day(12, 1),
  ),
];

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _scene == 2
          ? AllArtifactsPage(
              queue: _queue,
              done: _done,
              categories: _categories,
              now: _now,
              initialShelf: const Shelf(type: 'mapa'),
            )
          : const _Shell(),
    );
  }
}

/// The app's shell with Entregas in front, where Projetos was.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (_scene) {
        case 3:
          _newArtifact();
        case 4:
          _newArtifact(
            category: _atendimentos,
            type: _mapa,
            name: 'Mapa astral · Camila Rocha',
            deadline: _day(10, 23),
          );
        case 5:
          unawaited(
            showGoalSheet(
              context,
              now: _now,
              initialAmount: 10000,
              initialNext: true,
            ),
          );
        case 6:
          unawaited(
            showArtifactSheet(
              context,
              categories: const [],
              goals: _goals,
              now: _now,
            ),
          );
      }
    });
  }

  void _newArtifact({
    CatalogCategory? category,
    CatalogType? type,
    String? name,
    DateTime? deadline,
  }) {
    unawaited(
      showArtifactSheet(
        context,
        categories: _categories,
        goals: _goals,
        now: _now,
        initialCategory: category,
        initialType: type,
        initialName: name,
        initialDeadline: deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      body: ArtifactsPage(
        goals: _goals,
        queue: _queue,
        categories: _categories,
        now: _now,
        freeMinutes: 26 * 60,
        freeUntil: DateTime(2026, 10, 31, 23, 59),
        delivered: _done,
        initialShelf: const Shelf(category: 'cont'),
        onNewGoal: () => showGoalSheet(context, now: _now),
      ),
      floatingActionButton: AppFab(
        tooltip: l10n.artifactsNew,
        onPressed: _newArtifact,
      ),
      floatingActionButtonLocation: AppFab.location,
      bottomNavigationBar: AppBottomBar(
        currentIndex: 1,
        onSelected: (_) {},
        items: [
          AppBottomBarItem(
            iconData: AppIcons.time,
            label: l10n.shellTimelineTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.artifacts,
            label: l10n.shellArtifactsTab,
          ),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}
