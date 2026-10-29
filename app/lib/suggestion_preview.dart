import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';
import 'package:timeline/timeline.dart';

/// The suggestion, structured around the goal, and the conversation it
/// opens, full screen. `?s=<n>` picks the scene:
///
/// 1. Tempo, no goal yet: the suggestion is to set one; no action.
/// 2. Tempo, a goal short of its mark: a delivery that reaches it, with an
///    action made from the card.
/// 3. Conversar: the chat, full screen, opened on the suggestion's plan.
/// 4. Answering by voice: the recorder, whose stop sends.
/// 5. Sent the moment the recording stopped.
///
/// Nothing ships from here.
void main() {
  DemoClock.pin();
  withClock(DemoClock.around(clock), () => runApp(const _PreviewApp()));
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
      home: switch (_scene) {
        1 => const DemoApp(suggestion: _noGoal),
        2 => const DemoApp(suggestion: _delivery),
        _ => const _Chat(),
      },
    );
  }
}

DateTime get _today {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime get _friday {
  final today = _today;
  final ahead = (DateTime.friday - today.weekday) % 7;
  return today.add(Duration(days: ahead == 0 ? 7 : ahead));
}

AgentSuggestion _noGoal(AppLocalizations l10n) => AgentSuggestion(
  id: 'goal',
  focus: SuggestionFocus.goal,
  text:
      'Você ainda não tem um objetivo para novembro. Quanto quer faturar '
      'até o dia 30? Com esse número eu sei o que adiantar a cada dia.',
  validUntil: _today.add(const Duration(days: 1)),
  opening: const AgentReply(
    text: '',
    blocks: [
      CaptionBlock(
        'Quanto você quer faturar em novembro? Me diz um valor e eu monto '
        'o objetivo, com as entregas que já estão abertas.',
      ),
      ChoicesBlock(),
    ],
    options: [
      QuickReply(label: r'R$ 6.000', say: r'Quero faturar R$ 6.000.'),
      QuickReply(label: r'R$ 8.000', say: r'Quero faturar R$ 8.000.'),
    ],
  ),
);

AgentPlan _renataToday(AppLocalizations l10n) => AgentPlan(
  id: 'renata-today',
  changes: [
    PlanChange(
      kind: PlanChangeKind.addTask,
      title: 'Escrever a leitura · Renata',
      minutes: 120,
      at: _today.add(const Duration(hours: 14)),
    ),
  ],
);

AgentReply _opening(AppLocalizations l10n) => AgentReply(
  text: '',
  plan: _renataToday(l10n),
  options: const [
    QuickReply(label: 'Amanhã cedo', say: 'Prefiro amanhã cedo.'),
    QuickReply(label: 'Só 1 h hoje', say: 'Hoje só dá 1 hora.'),
  ],
  blocks: [
    const CaptionBlock(
      r'Faltam R$ 2.400 para os R$ 6.000 de novembro. O mapa da Renata '
      'vence sexta e é o que mais adianta: encaixo 2 h dele hoje.',
    ),
    ArtifactBlock(
      PeekArtifact(
        id: 'renata',
        title: l10n.demoDeliveryRenata,
        createdAt: _today.subtract(const Duration(days: 6)),
        deadline: _friday,
        done: 1,
        total: 4,
        next: const [
          PeekCard(id: 'r2', title: 'Escrever a leitura', minutes: 120),
          PeekCard(id: 'r3', title: 'Gravar o áudio', minutes: 45),
        ],
      ),
    ),
    const PlanBlock(),
    const ChoicesBlock(),
  ],
);

AgentSuggestion _delivery(AppLocalizations l10n) => AgentSuggestion(
  id: 'renata',
  focus: SuggestionFocus.delivery,
  text:
      r'Faltam R$ 2.400 para o objetivo de novembro, e o mapa da Renata '
      'vence sexta. Encaixo 2 h dele hoje às 14:00?',
  validUntil: _today.add(const Duration(hours: 14)),
  action: SuggestionAction(
    label: 'Encaixar às 14:00',
    plan: _renataToday(l10n),
  ),
  opening: _opening(l10n),
);

const _said =
    'Hoje à tarde eu tenho a consulta com a Júlia. Pode ser amanhã às nove?';

/// Scenes 3–5: the conversation as a page, on the delivery suggestion.
class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  late final _timeline = DemoTimelineRepository(context.l10n);
  late final _artifacts = DemoArtifactsRepository(context.l10n);
  late final _agent = DemoAgentRepository(
    context.l10n,
    timeline: _timeline,
    artifacts: _artifacts,
    offer: _delivery(context.l10n),
  );
  late final _cubit = _SeededAgent(_agent)
    ..open(opening: _opening(context.l10n));

  @override
  void initState() {
    super.initState();
    unawaited(_agent.suggestion());
    if (_scene == 5) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _cubit.say(_said, const Duration(seconds: 6)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AgentRepository>.value(
      value: _agent,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AgentCubit>.value(value: _cubit),
          BlocProvider<TimelineBloc>(
            create: (_) =>
                TimelineBloc(repository: _timeline)
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => _SeededVoice(recording: _scene == 4),
          ),
        ],
        child: const AgentSheet(focus: false),
      ),
    );
  }
}

/// The conversation, put where the scene needs it.
class _SeededAgent extends AgentCubit {
  _SeededAgent(AgentRepository repository) : super(repository: repository);

  /// Said by voice and sent, the answer on its way.
  void say(String text, Duration length) => emit(
    state.copyWith(
      entries: [
        ...state.entries,
        UserEntry(text, voice: length),
      ],
      busy: true,
    ),
  );
}

/// The microphone, mid-sentence when recording.
class _SeededVoice extends VoiceCubit {
  _SeededVoice({required bool recording})
    : super(recognizer: const DemoVoiceRecognizer()) {
    emit(
      recording
          ? VoiceState(
              status: VoiceStatus.listening,
              heard: 'Hoje à tarde eu tenho a consulta com a Júlia.',
              hearing: ' Pode ser amanhã às nove?',
              levels: [
                for (var i = 0; i < VoiceCubit.bars; i++)
                  0.2 + 0.6 * ((i * 7) % 11) / 10,
              ],
              elapsed: const Duration(seconds: 6),
            )
          : const VoiceState(),
    );
  }
}
