import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// {@template demo_artifacts_repository}
/// Entregas, answering from memory: a month of an astrologer's deliveries,
/// half of its goal already in.
///
/// A delivery written down, renamed, moved, delivered or removed stays so
/// until the page is left. The catalogue and the goals are drawn and kept
/// as they are: what they change is the server's arithmetic, which the demo
/// does not have.
/// {@endtemplate}
class DemoArtifactsRepository implements ArtifactsRepository {
  /// {@macro demo_artifacts_repository}
  DemoArtifactsRepository(AppLocalizations l10n) : data = demoArtifacts(l10n);

  /// What Entregas draws now. Set, it puts that back, as an undone plan
  /// does.
  ArtifactsData data;

  var _next = 0;

  @override
  Future<ArtifactsData> load() async => data;

  @override
  Future<ArtifactsData> create({
    required String title,
    String? typeId,
    int? minutes,
    int? value,
    int? blockMinutes,
    DateTime? deadline,
    bool top = false,
  }) async {
    final type = data.catalog
        .expand((shelf) => shelf.types)
        .where((it) => it.id == typeId)
        .firstOrNull;
    final artifact = Artifact(
      id: 'demo-artifact-${_next++}',
      title: title,
      minutes: minutes ?? type?.minutes ?? 60,
      createdAt: clock.now(),
      type: type,
      category: data.catalog
          .where((shelf) => shelf.types.contains(type))
          .firstOrNull,
      value: value ?? type?.price,
      blockMinutes: blockMinutes,
      deadline: deadline,
    );
    final queue = data.queue;
    return _put([
      if (top) artifact,
      ...queue,
      if (!top) artifact,
      ...data.done,
    ]);
  }

  @override
  Future<ArtifactsData> update(
    String id, {
    String? title,
    DateTime? Function()? deadline,
    String? notes,
    bool? done,
  }) async => _put([
    for (final it in data.artifacts)
      if (it.id == id)
        it.copyWith(
          title: title,
          deadline: deadline,
          notes: notes,
          doneAt: done == null ? null : () => done ? clock.now() : null,
        )
      else
        it,
  ]);

  @override
  Future<ArtifactsData> move(String id, int index) async {
    final queue = data.queue;
    final artifact = queue.where((it) => it.id == id).firstOrNull;
    if (artifact == null) return data;
    queue
      ..remove(artifact)
      ..insert(index.clamp(0, queue.length - 1), artifact);
    return _put([...queue, ...data.done]);
  }

  @override
  Future<ArtifactsData> delete(String id) async =>
      _put([...data.artifacts.where((it) => it.id != id)]);

  /// Writes [artifacts] down, open ones first and delivered ones newest
  /// first, as the server answers.
  ArtifactsData _put(List<Artifact> artifacts) {
    final done = artifacts.where((it) => it.isDone).toList()
      ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
    return data = ArtifactsData(
      artifacts: [...artifacts.where((it) => !it.isDone), ...done],
      catalog: data.catalog,
      goals: data.goals,
      schedule: data.schedule,
      topTypes: data.topTypes,
    );
  }

  // The catalogue and the goals: drawn, not changed.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<ArtifactsData>.value(data);
}

/// The demo's deliveries, counted from today.
ArtifactsData demoArtifacts(AppLocalizations l10n) {
  final now = clock.now();
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
