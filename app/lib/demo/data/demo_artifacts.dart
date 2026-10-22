import 'package:artifacts/artifacts.dart';
import 'package:l10n/l10n.dart';

/// {@template demo_artifacts_repository}
/// Entregas, answering from memory: a month of an astrologer's deliveries,
/// half of its goal already in.
///
/// Every write answers with the same data, so the page can be looked at and
/// its rows opened, and nothing it is asked to change sticks.
/// {@endtemplate}
class DemoArtifactsRepository implements ArtifactsRepository {
  /// {@macro demo_artifacts_repository}
  DemoArtifactsRepository(AppLocalizations l10n) : data = demoArtifacts(l10n);

  /// What every call answers with.
  final ArtifactsData data;

  @override
  Future<ArtifactsData> load() async => data;

  // Every other call is a write, and each answers with everything, as the
  // server does.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<ArtifactsData>.value(data);
}

/// The demo's deliveries, counted from today.
ArtifactsData demoArtifacts(AppLocalizations l10n) {
  final now = DateTime.now();
  DateTime inDays(int days) => DateTime(now.year, now.month, now.day + days);
  final month = DateTime(now.year, now.month);

  final mapa = CatalogType(
    id: 'mapa',
    name: l10n.demoTypeChart,
    minutes: 180,
    price: 350,
    blockMinutes: 60,
  );
  final post = CatalogType(id: 'post', name: l10n.demoTypePost, minutes: 60);
  final atendimentos = CatalogCategory(
    id: 'atend',
    name: l10n.demoShelfSessions,
    types: [mapa],
  );
  final conteudo = CatalogCategory(
    id: 'cont',
    name: l10n.demoShelfContent,
    types: [post],
  );

  Artifact artifact(
    String id,
    String title,
    CatalogType type,
    CatalogCategory category, {
    required int due,
    int done = 0,
  }) => Artifact(
    id: id,
    title: title,
    minutes: type.minutes,
    doneMinutes: done,
    createdAt: month,
    type: type,
    category: category,
    value: type.price,
    deadline: inDays(due),
  );

  return ArtifactsData(
    artifacts: [
      artifact(
        'renata',
        l10n.demoDeliveryRenata,
        mapa,
        atendimentos,
        due: 2,
        done: 120,
      ),
      artifact('post', l10n.demoDeliveryPost, post, conteudo, due: 3),
      artifact('julia', l10n.demoDeliveryJulia, mapa, atendimentos, due: 6),
      artifact('pedro', l10n.demoDeliveryPedro, mapa, atendimentos, due: 9),
    ],
    catalog: [atendimentos, conteudo],
    goals: [
      Goal(
        id: 'mes',
        kind: GoalKind.money,
        period: GoalPeriod.month,
        target: 6000,
        done: 3850,
        queued: 1050,
        start: month,
        end: DateTime(now.year, now.month + 1),
      ),
    ],
    schedule: Schedule(
      needMinutes: 8 * 60 + 30,
      freeMinutes: 31 * 60,
      until: DateTime(now.year, now.month + 1, 0),
    ),
    topTypes: [mapa],
  );
}
