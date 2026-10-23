import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/home/view/greeting.dart';
import 'package:timeline/timeline.dart';

/// The delivery-first Lista, Calendário and Entregas, against fixed data.
///
/// `?s=1` Lista at 10:00, `2` Lista after the day, `3` Calendário at 10:00,
/// `4` Calendário on tomorrow morning, `5` Entregas. Nothing ships from here.
void main() {
  final at = _scene == 2 ? _at(22, 10) : _at(10);
  withClock(Clock.fixed(at), () => runApp(const _PreviewApp()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

final DateTime _today = DateTime(2026, 10, 23);

DateTime _at(int h, [int m = 0, int day = 0]) =>
    DateTime(_today.year, _today.month, _today.day + day, h, m);

TimelineEvent _task(
  String id,
  String title,
  DateTime start,
  int minutes, {
  TimelineSection section = TimelineSection.dia,
  String? artifact,
  String? routine,
  bool started = false,
  String notes = '',
}) => TimelineEvent(
  notes: notes,
  id: id,
  title: title,
  section: section,
  startTime: start,
  endTime: start.add(Duration(minutes: minutes)),
  durationMinutes: minutes,
  started: started,
  routine: routine,
  artifactId: artifact == null ? null : 'a-$artifact',
  artifactTitle: artifact,
);

TimelineEvent _backlog(String id, String title, int minutes, {String? a}) =>
    _task(
      id,
      title,
      _at(0),
      minutes,
      section: TimelineSection.backlog,
      artifact: a,
    );

const _renata = 'Mapa astral · Renata';
const _post = 'Post · Lua cheia em Touro';
const _julia = 'Mapa astral · Júlia';
const _curso = 'Curso de tarô · módulo 2';

// Today, at ten.
final TimelineEvent _renataDone = _task(
  'r1',
  'Levantar o mapa',
  _at(8, 30),
  60,
);
final TimelineEvent _renataNow = _task(
  'r2',
  'Escrever a leitura',
  _at(9, 40),
  60,
  section: TimelineSection.agora,
  artifact: _renata,
  started: true,
);
final TimelineEvent _renataNext = _task(
  'r3',
  'Gravar o áudio',
  _at(10, 45),
  30,
  artifact: _renata,
);
final TimelineEvent _reply = _task(
  'l1',
  'Responder a Júlia sobre a data',
  _at(11, 20),
  15,
);
final TimelineEvent _lunch = _task(
  'l2',
  'Almoço',
  _at(12),
  60,
  routine: 'daily',
);
final TimelineEvent _post1 = _task(
  'p1',
  'Escrever o roteiro',
  _at(13),
  45,
  artifact: _post,
);
final TimelineEvent _post2 = _task(
  'p2',
  'Gravar o reels',
  _at(13, 50),
  30,
  artifact: _post,
);
final TimelineEvent _post3 = _task(
  'p3',
  'Editar e publicar',
  _at(14, 25),
  35,
  artifact: _post,
);
final TimelineEvent _bill = _task(
  'l3',
  'Pagar o boleto da internet',
  _at(15, 5),
  15,
);
final TimelineEvent _julia1 = _task(
  'j1',
  'Levantar o mapa',
  _at(15, 25),
  60,
  artifact: _julia,
);

// Tomorrow.
final TimelineEvent _coffee = _task('c1', 'Passar o café', _at(7, 0, 1), 20);
final TimelineEvent _meditate = _task('c2', 'Meditar', _at(7, 25, 1), 25);
final TimelineEvent _dishes = _task('c3', 'Lavar a louça', _at(7, 55, 1), 25);
final TimelineEvent _julia2 = _task(
  'j2',
  'Interpretar os trânsitos',
  _at(8, 50, 1),
  60,
  artifact: _julia,
  notes:
      'Nasceu em 12/03/1994, às 06:40, em Campinas. Quer olhar carreira '
      'e a mudança para Lisboa no ano que vem.',
);
final TimelineEvent _site1 = _task(
  's1',
  'Trocar as fotos da home',
  _at(9, 55, 1),
  15,
  artifact: 'Revisar o site',
);
final TimelineEvent _site2 = _task(
  's2',
  'Ajustar os textos',
  _at(10, 15, 1),
  15,
  artifact: 'Revisar o site',
);
final TimelineEvent _site3 = _task(
  's3',
  'Publicar',
  _at(10, 35, 1),
  15,
  artifact: 'Revisar o site',
);
final TimelineEvent _accountant = _task(
  'l4',
  'Ligar para o contador',
  _at(10, 55, 1),
  15,
);

// Para depois.
final List<TimelineEvent> _backlogCourse = [
  _backlog('b1', 'Gravar a aula 3', 90, a: _curso),
  _backlog('b2', 'Montar os slides da aula 4', 60, a: _curso),
];
final TimelineEvent _filter = _backlog('b3', 'Trocar o filtro da água', 20);

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
      home: const _Phone(),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone();

  @override
  Widget build(BuildContext context) {
    final entregas = _scene == 5;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: entregas
          ? BlocProvider(
              create: (_) => ArtifactsCubit(
                repository: DemoArtifactsRepository(context.l10n),
                initial: ArtifactsState(
                  status: ArtifactsStatus.ready,
                  data: _deliveries(),
                ),
              ),
              child: const ArtifactsPage(shown: 8),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  _Switch(calendar: _scene >= 3),
                  Expanded(
                    child: switch (_scene) {
                      2 => const _ListAfterHours(),
                      3 => const _Calendar(),
                      4 => const _CalendarTomorrow(),
                      _ => const _List(),
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: AppFab(onPressed: () {}),
      bottomNavigationBar: AppBottomBar(
        items: [
          AppBottomBarItem(
            iconData: AppIcons.time,
            label: context.l10n.shellTimelineTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.artifacts,
            label: context.l10n.shellArtifactsTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.menu,
            label: context.l10n.shellMenuTab,
          ),
        ],
        currentIndex: entregas ? 1 : 0,
        onSelected: (_) {},
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    return Padding(
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
                  greeting(context.l10n, now, null),
                  style: AppTypography.headline,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(longDate(context.l10n, now), style: AppTypography.label),
              ],
            ),
          ),
          const AppDayClock(),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.calendar});

  final bool calendar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          AppSegmented(
            segments: [
              AppSegment(
                label: context.l10n.timelineModeList,
                iconData: AppIcons.prioritize,
              ),
              AppSegment(
                label: context.l10n.timelineModeCalendar,
                iconData: AppIcons.calendar,
              ),
            ],
            selected: calendar ? 1 : 0,
            onSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label, {this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? AppSpacing.s2 : AppSpacing.s6,
        bottom: AppSpacing.s2,
      ),
      child: Text(label, style: AppTypography.title),
    );
  }
}

/// The running delivery: its next task in Lista, every line on the
/// calendar.
Widget _now({bool timeline = false}) => DeliveryTile(
  title: _renata,
  timeline: timeline,
  done: [_renataDone],
  tasks: [_renataNow, _renataNext],
  onPauseToggled: () {},
  onAdjusted: (_) {},
  onDone: () {},
);

Widget _gap(Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.s2),
  child: child,
);

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s16 * 2,
      ),
      children: children,
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scroll(
      children: [
        _Heading(l10n.sectionNow, first: true),
        _now(),
        _Heading(l10n.sectionToday),
        _gap(EventTile(card: _reply)),
        _gap(DeliveryTile(title: _post, tasks: [_post1, _post2, _post3])),
        _gap(EventTile(card: _bill)),
        _gap(DeliveryTile(title: _julia, tasks: [_julia1])),
        const _Ahead(count: 6),
        _Heading(l10n.stageLater),
        _gap(DeliveryTile(title: _curso, tasks: _backlogCourse)),
        _gap(EventTile(card: _filter)),
      ],
    );
  }
}

class _ListAfterHours extends StatelessWidget {
  const _ListAfterHours();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scroll(
      children: [
        _Heading(l10n.sectionNow, first: true),
        const DayOverTile(workDay: WorkDay.standard, over: true),
        _Heading(l10n.sectionTomorrow),
        _gap(DeliveryTile(title: _julia, tasks: [_julia2])),
        _gap(
          DeliveryTile(
            title: 'Revisar o site',
            tasks: [_site1, _site2, _site3],
          ),
        ),
        _gap(EventTile(card: _accountant)),
        _gap(DeliveryTile(title: _post, tasks: [_post2, _post3])),
        const _Ahead(count: 5),
        _Heading(l10n.stageLater),
        _gap(DeliveryTile(title: _curso, tasks: _backlogCourse)),
        _gap(EventTile(card: _filter)),
      ],
    );
  }
}

/// Where the list stops: how many more have an hour, and the way to them.
class _Ahead extends StatelessWidget {
  const _Ahead({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: Row(
        children: [
          const AppIcon(
            iconData: AppIcons.calendar,
            size: AppSpacing.s4,
            color: AppColors.ink3,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              context.l10n.stageAhead(count),
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ),
          Text(
            context.l10n.stageAheadOpen,
            style: AppTypography.labelStrong.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

/// [minutes] of the calendar, the room under a card taken off.
double _tall(int minutes) =>
    (minutes < 30 ? 30 : minutes) * TimelineScale.perMinute - AppSpacing.s1;

Widget _scaled(TimelineEvent card) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.s1),
  child: SizedBox(
    height: _tall(card.durationMinutes),
    child: EventTile(card: card, preview: true),
  ),
);

Widget _run(String title, List<TimelineEvent> tasks, {bool routine = false}) {
  final minutes = tasks.last.endTime.difference(tasks.first.startTime);
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s1),
    child: DeliveryTile(
      title: title,
      tasks: tasks,
      routine: routine,
      height: _tall(minutes.inMinutes),
    ),
  );
}

/// A free stretch, as the calendar draws it.
class _Free extends StatelessWidget {
  const _Free({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
      child: Container(
        height: _tall(to.difference(from).inMinutes.clamp(0, 60)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: AppColors.freeFill,
          border: Border.all(color: AppColors.freeEdge),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(
              iconData: AppIcons.plus,
              size: AppSpacing.s4,
              color: AppColors.freeInk,
            ),
            const Spacer(),
            Text(
              '${hhmm(from)}–${hhmm(to)}',
              style: AppTypography.label.copyWith(color: AppColors.freeInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scroll(
      children: [
        _Heading(l10n.sectionNow, first: true),
        _now(timeline: true),
        _Heading(l10n.sectionToday),
        _scaled(_reply),
        _Free(from: _at(11, 35), to: _at(12)),
        _scaled(_lunch),
        _run(_post, [_post1, _post2, _post3]),
        _scaled(_bill),
        _run(_julia, [_julia1]),
      ],
    );
  }
}

class _CalendarTomorrow extends StatelessWidget {
  const _CalendarTomorrow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scroll(
      children: [
        _Heading(l10n.sectionTomorrow, first: true),
        _run('Café da manhã', [_coffee, _meditate, _dishes], routine: true),
        _Free(from: _at(8, 20, 1), to: _at(8, 45, 1)),
        _run(_julia, [_julia2]),
        _run('Revisar o site', [_site1, _site2, _site3]),
        _scaled(_accountant),
        _Free(from: _at(11, 10, 1), to: _at(12, 0, 1)),
      ],
    );
  }
}

/// Entregas on the 23rd at ten: one due today and behind, one tomorrow on
/// pace, Júlia's half done with half her time gone, a course far off and
/// already behind, and one with no deadline.
ArtifactsData _deliveries() {
  List<ArtifactTask> tasks(String id, int total, int done) => [
    for (var i = 0; i < total; i++)
      ArtifactTask(
        id: '$id-$i',
        title: 'Etapa ${i + 1}',
        minutes: 30,
        place: i < done ? TaskPlace.done : TaskPlace.queue,
      ),
  ];
  Artifact artifact(
    String id,
    String title, {
    required int minutes,
    required DateTime createdAt,
    required List<ArtifactTask> steps,
    required CatalogType type,
    DateTime? deadline,
    int? value,
  }) => Artifact(
    type: type,
    id: id,
    title: title,
    minutes: minutes,
    createdAt: createdAt,
    deadline: deadline,
    value: value,
    tasks: steps,
  );

  const chart = CatalogType(id: 'mapa', name: 'Mapa astral', minutes: 300);
  const post = CatalogType(id: 'post', name: 'Post', minutes: 120);
  const course = CatalogType(id: 'curso', name: 'Curso', minutes: 600);
  const site = CatalogType(id: 'site', name: 'Site', minutes: 180);

  return ArtifactsData(
    artifacts: [
      artifact(
        'renata',
        type: chart,
        _renata,
        minutes: 300,
        createdAt: DateTime(2026, 10, 16),
        deadline: _today,
        value: 350,
        steps: tasks('r', 5, 3),
      ),
      artifact(
        'post',
        type: post,
        _post,
        minutes: 120,
        createdAt: DateTime(2026, 10, 20),
        deadline: DateTime(2026, 10, 24),
        steps: tasks('p', 4, 3),
      ),
      artifact(
        'julia',
        type: chart,
        _julia,
        minutes: 360,
        createdAt: DateTime(2026, 10, 16),
        deadline: DateTime(2026, 10, 29),
        value: 350,
        steps: tasks('j', 10, 5),
      ),
      artifact(
        'curso',
        type: course,
        _curso,
        minutes: 600,
        createdAt: DateTime(2026, 10),
        deadline: DateTime(2026, 11, 14),
        value: 1200,
        steps: tasks('c', 8, 1),
      ),
      artifact(
        'site',
        type: site,
        'Revisar o site',
        minutes: 180,
        createdAt: DateTime(2026, 10, 10),
        steps: tasks('s', 4, 1),
      ),
    ],
    schedule: Schedule(
      needMinutes: 24 * 60,
      freeMinutes: 31 * 60,
      until: DateTime(2026, 10, 31),
    ),
  );
}
