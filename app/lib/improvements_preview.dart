import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/home.dart';
import 'package:lunna/menu/menu.dart';
import 'package:timeline/timeline.dart';

/// The design of the "improvements" round, drawn by the real widgets
/// against canned data. `?s=<n>` picks the scene:
///
/// 1. Calendário: notes and projects on the cards, in the room they have.
/// 2. A task's page: no circle before the name, done said in words.
/// 3. Menu: Feitas, and the + where it is on every tab.
/// 4. Feitas: the archive of what was done.
/// 5. Recording on Tempo, tapped: one panel, send in the +'s place.
/// 6. Recording on Tempo, held: the same panel, the finger on the mic.
///
/// Nothing ships from here.
void main() {
  final today = DateTime.now();
  final now = DateTime(today.year, today.month, today.day, 10, 12);
  withClock(Clock.fixed(now), () => runApp(const _PreviewApp()));
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

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
      home: RepositoryProvider<TimelineRepository>(
        create: (_) => _FakeTimeline(),
        child: BlocProvider(
          create: (context) =>
              TimelineBloc(repository: context.read<TimelineRepository>())
                ..add(const TimelineRequested()),
          child: switch (_scene) {
            2 => const EventPage(id: 'proposta'),
            3 => const _Tab(index: 2, child: MenuPage()),
            4 => DoneArchivePage(done: _done(), onOpen: (_) {}),
            5 => const _Tempo(recording: _Recording.tapped),
            6 => const _Tempo(recording: _Recording.held),
            _ => const _Tempo(),
          },
        ),
      ),
    );
  }
}

enum _Recording { none, tapped, held }

/// Tempo as the shell draws it, with the dock at its foot.
class _Tempo extends StatelessWidget {
  const _Tempo({this.recording = _Recording.none});

  final _Recording recording;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width =
        MediaQuery.sizeOf(context).width - 2 * kFloatingActionButtonMargin;
    final fab = AppFab(tooltip: l10n.shellWriteDown, onPressed: () {});

    return _Tab(
      index: 0,
      location: FloatingActionButtonLocation.centerFloat,
      fab: SizedBox(
        width: width,
        child: recording == _Recording.none
            ? Row(
                children: [
                  Expanded(
                    child: AskBar(onOpen: () {}, onListen: () {}),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  fab,
                ],
              )
            : AskRecorder(
                voice: VoiceState(
                  status: VoiceStatus.listening,
                  heard: recording == _Recording.held
                      ? 'Coloca o dentista amanhã às nove'
                      : 'Coloca o dentista amanhã às nove e empurra a '
                            'revisão da proposta pra depois do almoço',
                  levels: const [
                    0.2, 0.35, 0.5, 0.3, 0.6, 0.8, 0.55, 0.4, 0.7, 0.9, //
                    0.6, 0.3, 0.25, 0.5, 0.75, 0.65, 0.4, 0.3, 0.55, 0.8,
                    0.7, 0.45, 0.3, 0.2, 0.4, 0.6, 0.5, 0.35,
                  ],
                  elapsed: Duration(
                    seconds: recording == _Recording.held ? 4 : 9,
                  ),
                ),
                held: recording == _Recording.held,
                onSend: () {},
                onDiscard: () {},
                onReview: () {},
              ),
      ),
      child: SafeArea(
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
                          greeting(l10n, clock.now(), 'Pietro'),
                          style: AppTypography.headline,
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          longDate(l10n, clock.now()),
                          style: AppTypography.label,
                        ),
                      ],
                    ),
                  ),
                  const AppDayClock(),
                ],
              ),
            ),
            const TimelineModeSwitchHost(),
            Expanded(
              child: TimelineList(
                aim: TimelineAim(),
                onWriteDown: (_) {},
                onCardTap: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the shell's tabs: the page, the + and the bar, as the shell
/// places them.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.index,
    required this.child,
    this.fab,
    this.location,
  });

  final int index;
  final Widget child;
  final Widget? fab;
  final FloatingActionButtonLocation? location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      extendBody: true,
      body: child,
      floatingActionButton:
          fab ?? AppFab(tooltip: l10n.shellWriteDown, onPressed: () {}),
      floatingActionButtonLocation: location ?? AppFab.location,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      bottomNavigationBar: AppBottomBar(
        currentIndex: index,
        onSelected: (_) {},
        items: [
          AppBottomBarItem(
            iconData: AppIcons.time,
            label: l10n.shellTimelineTab,
          ),
          AppBottomBarItem(
            iconData: AppIcons.things,
            label: l10n.shellProjectsTab,
          ),
          AppBottomBarItem(iconData: AppIcons.menu, label: l10n.shellMenuTab),
        ],
      ),
    );
  }
}

/// The mode switch, with the cubit it needs.
class TimelineModeSwitchHost extends StatelessWidget {
  /// Draws Tempo's switch on the calendar.
  const TimelineModeSwitchHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimelineModeCubit(),
      child: const TimelineModeSwitch(),
    );
  }
}

DateTime _at(int hour, int minute, {int day = 0}) {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day + day, hour, minute);
}

TimelineEvent _card(
  String id,
  String title,
  DateTime start,
  int minutes, {
  bool event = false,
  bool started = false,
  String notes = '',
  String? project,
}) {
  final end = start.add(Duration(minutes: minutes));
  final now = clock.now();
  return TimelineEvent(
    id: id,
    title: title,
    kind: event ? CardKind.event : CardKind.task,
    fixed: event,
    section: !start.isAfter(now) && end.isAfter(now)
        ? TimelineSection.agora
        : TimelineSection.dia,
    startTime: start,
    endTime: end,
    durationMinutes: minutes,
    started: started,
    notes: notes,
    projectId: project,
    projectTitle: project,
  );
}

/// The day the scenes draw, at 10:12.
final _day = <TimelineEvent>[
  _card(
    'roteiro',
    'Escrever o roteiro do episódio 4',
    _at(9, 50),
    60,
    started: true,
    project: 'Podcast',
    notes: 'Abrir com a história da feira de Pinheiros',
  ),
  _card(
    'carla',
    'Reunião com a Carla',
    _at(10, 55),
    30,
    event: true,
    notes: 'Levar os números de setembro e a proposta revisada',
  ),
  _card(
    'proposta',
    'Revisar a proposta da Ana',
    _at(11, 30),
    50,
    project: 'Reforma do apê',
    notes:
        'Conferir o orçamento do marceneiro\n'
        'https://www.marcenariasilva.com.br/orcamento/2291\n'
        'Ver se a bancada entra no prazo de novembro',
  ),
  _card('almoco', 'Almoço com a Bia', _at(12, 30), 60, event: true),
  _card(
    'mercado',
    'Comprar leite e ovos',
    _at(13, 35),
    30,
    notes: 'Pão integral também, e café',
  ),
  _card(
    'gravar',
    'Gravar o episódio 4',
    _at(14, 10),
    90,
    project: 'Podcast',
    notes:
        'Testar o microfone novo antes de começar. O roteiro está na pasta '
        'do Drive; chamar o Léo às 15h para a parte da entrevista.',
  ),
  _card('emails', 'Responder e-mails', _at(15, 45), 30),
];

List<TimelineEvent> _done() => [
  _card(
    'd1',
    'Mandar a fatura de outubro',
    _at(9, 40),
    15,
    notes: 'Enviada pelo portal; protocolo 88213',
  ),
  _card(
    'd2',
    'Pesquisar marceneiros',
    _at(8, 55),
    45,
    project: 'Reforma do apê',
    notes: 'Silva Marcenaria e Casa do Móvel pediram foto da planta',
  ),
  _card(
    'd3',
    'Correr 5 km',
    _at(7, 30),
    40,
    notes: 'Parque Villa-Lobos, 31 min',
  ),
  _card(
    'd4',
    'Editar o episódio 3',
    _at(18, 10, day: -1),
    120,
    project: 'Podcast',
    notes: 'Cortar a parte do trânsito; trilha da Free Music Archive',
  ),
  _card('d5', 'Ligar para a mãe', _at(12, 20, day: -1), 20),
  _card(
    'd6',
    'Renovar o passaporte',
    _at(16, 0, day: -3),
    60,
    notes: 'Retirar na PF da Lapa a partir do dia 4',
  ),
  _card('d7', 'Trocar o filtro da água', _at(10, 5, day: -3), 15),
];

/// A day that answers from the canned cards and ignores every write.
class _FakeTimeline implements TimelineRepository {
  Timeline get _timeline {
    final tasks = [
      for (final card in _day)
        if (card.isTask) card,
    ];
    return Timeline(
      tasks: tasks,
      cards: _day,
      backlog: [
        TimelineEvent(
          id: 'fotos',
          title: 'Organizar as fotos da viagem',
          section: TimelineSection.backlog,
          startTime: clock.now(),
          endTime: clock.now(),
          durationMinutes: 60,
        ),
      ],
    );
  }

  @override
  Future<Timeline> fetch({int days = TimelineRepository.defaultDays}) async =>
      _timeline;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(_timeline);
}
