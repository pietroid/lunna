import 'package:agent/agent.dart';
import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/data/demo_repositories.dart';
import 'package:lunna/home/home.dart';
import 'package:timeline/timeline.dart';

/// Preview of the declutter delivery: Tempo's Lista with only loose tasks
/// in Para depois, and a delivery's page in three tabs. `?s=1` Tempo,
/// `?s=2` the delivery's Pendentes, `?s=3` its Feitas, `?s=4` Tempo's
/// Calendário. Nothing ships.
void main() {
  final now = DateTime(2026, 10, 23, 10);
  withClock(Clock.fixed(now), () => runApp(const _PreviewApp()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

final TimelineMode _mode = _scene == 4
    ? TimelineMode.calendar
    : TimelineMode.list;

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
      home: const _Scene(),
    );
  }
}

class _NoToken extends TokenProvider {
  const _NoToken();

  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> refreshToken() async => null;
}

/// Answers with the canned day and refuses nothing it is never asked.
class _FakeTimeline extends TimelineRepository {
  _FakeTimeline(this.day)
    : super(
        apiClient: ApiClient(
          baseUrl: 'http://preview.invalid',
          tokenProvider: const _NoToken(),
        ),
      );

  final Timeline day;

  @override
  Future<Timeline> fetch({int days = TimelineRepository.defaultDays}) async =>
      day;
}

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, 23 + day, hour, minute);

TimelineEvent _task(
  String id,
  String title,
  int day,
  int h,
  int m,
  int minutes, {
  String? delivery,
  String? deliveryTitle,
  bool running = false,
}) {
  final start = _at(day, h, m);
  return TimelineEvent(
    id: id,
    title: title,
    section: running ? TimelineSection.agora : TimelineSection.dia,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    started: running,
    remainingSeconds: running ? 25 * 60 : 0,
    artifactId: delivery,
    artifactTitle: deliveryTitle,
  );
}

TimelineEvent _waiting(String id, String title, int minutes, {String? of}) =>
    TimelineEvent(
      id: id,
      title: title,
      section: TimelineSection.backlog,
      startTime: _at(0, 10, 0),
      endTime: _at(0, 10, 0),
      durationMinutes: minutes,
      artifactId: of,
      artifactTitle: of == null ? null : 'Mapa astral · Renata',
    );

const _renata = 'renata';
const _renataTitle = 'Mapa astral · Renata';
const _post = 'post';
const _postTitle = 'Post · Lua cheia em Touro';

Timeline _day() {
  final tasks = [
    _task(
      'calc',
      'Calcular o mapa',
      0,
      9,
      30,
      60,
      delivery: _renata,
      deliveryTitle: _renataTitle,
      running: true,
    ),
    _task(
      'leitura',
      'Escrever a leitura',
      0,
      10,
      35,
      60,
      delivery: _renata,
      deliveryTitle: _renataTitle,
    ),
    _task('julia', 'Responder a Júlia', 0, 11, 40, 30),
    _task(
      'rascunho',
      'Rascunhar o texto',
      0,
      12,
      15,
      45,
      delivery: _post,
      deliveryTitle: _postTitle,
    ),

    _task(
      'audio',
      'Gravar o áudio',
      1,
      9,
      0,
      45,
      delivery: _renata,
      deliveryTitle: _renataTitle,
    ),
    _task(
      'arte',
      'Fazer a arte',
      1,
      10,
      0,
      45,
      delivery: _post,
      deliveryTitle: _postTitle,
    ),
  ];
  return Timeline(
    tasks: tasks,
    cards: tasks,
    backlog: [
      _waiting('lampada', 'Trocar a lâmpada da sala', 15),
      _waiting('revisar', 'Revisar a leitura', 30, of: _renata),
      _waiting('passaporte', 'Renovar o passaporte', 30),
      _waiting('enviar', 'Enviar para a Renata', 10, of: _renata),
      _waiting('presente', 'Comprar o presente da Bia', 20),
    ],
  );
}

ArtifactsData _deliveries(AppLocalizations l10n) {
  final demo = demoArtifacts(l10n);
  final renata = Artifact(
    id: _renata,
    title: _renataTitle,
    minutes: 300,
    doneMinutes: 120,
    createdAt: DateTime(2026, 10, 17),
    deadline: DateTime(2026, 10, 27),
    value: 350,
    type: demo.catalog.first.types.first,
    category: demo.catalog.first,
    tasks: [
      ArtifactTask(
        id: 'dados',
        title: 'Pedir os dados de nascimento',
        minutes: 10,
        place: TaskPlace.done,
        doneAt: _at(-2, 16, 40),
      ),
      ArtifactTask(
        id: 'software',
        title: 'Montar o mapa no software',
        minutes: 30,
        place: TaskPlace.done,
        notes: 'Casa 7 em Libra, conferir o ascendente com ela.',
        doneAt: _at(-1, 11, 5),
      ),
      ArtifactTask(
        id: 'pesquisa',
        title: 'Ler sobre Saturno na casa 10',
        minutes: 30,
        place: TaskPlace.done,
        doneAt: _at(0, 9, 20),
      ),
      const ArtifactTask(
        id: 'calc',
        title: 'Calcular o mapa',
        minutes: 60,
        place: TaskPlace.queue,
      ),
      const ArtifactTask(
        id: 'leitura',
        title: 'Escrever a leitura',
        minutes: 60,
        place: TaskPlace.queue,
      ),
      const ArtifactTask(
        id: 'audio',
        title: 'Gravar o áudio',
        minutes: 45,
        place: TaskPlace.queue,
      ),
      const ArtifactTask(
        id: 'revisar',
        title: 'Revisar a leitura',
        minutes: 30,
        place: TaskPlace.backlog,
      ),
      const ArtifactTask(
        id: 'enviar',
        title: 'Enviar para a Renata',
        minutes: 10,
        place: TaskPlace.backlog,
      ),
    ],
  );
  return ArtifactsData(
    artifacts: [renata, ...demo.artifacts.where((a) => a.id != _renata)],
    catalog: demo.catalog,
    schedule: demo.schedule,
  );
}

class _Scene extends StatefulWidget {
  const _Scene();

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  late final _timeline = _FakeTimeline(_day());
  late final _artifacts = DemoArtifactsRepository(context.l10n)
    ..data = _deliveries(context.l10n);
  late final _demoDay = DemoTimelineRepository(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _demoDay,
    artifacts: _artifacts,
  );

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TimelineRepository>.value(value: _timeline),
        RepositoryProvider<AgentRepository>.value(value: _agent),
        RepositoryProvider<TimelineAim>(create: (_) => TimelineAim()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineBloc>(
            create: (_) =>
                TimelineBloc(repository: _timeline)
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<TimelineModeCubit>(
            create: (_) => TimelineModeCubit(initial: _mode),
          ),
          BlocProvider<AgentCubit>(
            create: (_) => AgentCubit(repository: _agent),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => VoiceCubit(recognizer: const DemoVoiceRecognizer()),
          ),
          BlocProvider<ArtifactsCubit>(
            create: (_) => ArtifactsCubit(
              repository: _artifacts,
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: _artifacts.data,
              ),
            ),
          ),
        ],
        child: _scene == 1 || _scene == 4
            ? const _Tempo()
            : ArtifactPage(id: _renata, initialTab: _scene == 3 ? 2 : 1),
      ),
    );
  }
}

/// Tempo in Lista, as the shell draws it.
class _Tempo extends StatelessWidget {
  const _Tempo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                AppSpacing.s5,
                AppSpacing.s6,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(l10n, now, null),
                          style: AppTypography.headline,
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(longDate(l10n, now), style: AppTypography.label),
                      ],
                    ),
                  ),
                  const AppDayClock(),
                ],
              ),
            ),
            const TimelineModeSwitch(),
            Expanded(
              child: TimelineList(
                mode: _mode,
                aim: context.read<TimelineAim>(),
                onCardTap: (card) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventPage(id: card.id),
                  ),
                ),
                onDeliveryTap: (id) => openArtifact(context, id, tab: 1),
                onWriteDown: (_) {},
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AskDock(
        day: clock.now,
        fab: AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: AppBottomBar(
        currentIndex: 0,
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
