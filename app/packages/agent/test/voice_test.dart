import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeline/timeline.dart';

/// A recognizer the test speaks through.
class _FakeRecognizer implements VoiceRecognizer {
  _FakeRecognizer([this.availability = VoiceAvailability.available]);

  VoiceAvailability availability;

  int sessions = 0;
  int stops = 0;
  int cancels = 0;

  late VoiceWords _onWords;
  late ValueChanged<double> _onLevel;
  late VoidCallback _onEnd;

  @override
  Future<VoiceAvailability> prepare() async => availability;

  @override
  Future<void> listen({
    required VoiceWords onWords,
    required ValueChanged<double> onLevel,
    required VoidCallback onEnd,
  }) async {
    sessions++;
    _onWords = onWords;
    _onLevel = onLevel;
    _onEnd = onEnd;
  }

  void say(String words, {bool done = false}) => _onWords(words, done: done);

  void level(double level) => _onLevel(level);

  /// The platform ends the session on its own, as Android does after a
  /// pause.
  void end() => _onEnd();

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;
}

class _MockRepository extends Mock implements AgentRepository {}

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

final _now = DateTime(2026, 10, 15, 9, 41);

/// Runs [body] on a clock and timers the test moves by hand.
void _onFakeTime(void Function(FakeAsync async) body) {
  fakeAsync((async) {
    withClock(async.getClock(_now), () => body(async));
  });
}

void main() {
  _suggestionCardTests();

  group('VoiceCubit', () {
    test('shows the words as they come and settles them', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        expect(cubit.state.status, VoiceStatus.listening);

        recognizer.say('Amanhã de manhã');
        expect(cubit.state.hearing, 'Amanhã de manhã');
        expect(cubit.state.heard, isEmpty);

        recognizer.say('Amanhã de manhã encaixa estudo', done: true);
        expect(cubit.state.heard, 'Amanhã de manhã encaixa estudo');
        expect(cubit.state.hearing, isEmpty);

        // A repeat from the same session, after its last words, is dropped.
        recognizer.say('Amanhã');
        expect(cubit.state.text, 'Amanhã de manhã encaixa estudo');
        unawaited(cubit.close());
      });
    });

    test('a session that fails at once is not started again', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        // No microphone (a simulator): the platform ends it straight away.
        recognizer.end();
        async.flushMicrotasks();

        expect(recognizer.sessions, 1);
        expect(cubit.state.status, VoiceStatus.unavailable);
        unawaited(cubit.close());
      });
    });

    test('a quiet session that ran a while is followed by another', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));
        recognizer.end();
        async.flushMicrotasks();

        expect(recognizer.sessions, 2);
        expect(cubit.state.status, VoiceStatus.listening);
        unawaited(cubit.close());
      });
    });

    test('a pause does not end the recording: the next session joins on', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer
          ..say('Encaixa estudo')
          ..end();
        async.flushMicrotasks();

        expect(recognizer.sessions, 2);
        expect(cubit.state.status, VoiceStatus.listening);

        recognizer.say('e empurra a academia');
        expect(cubit.state.text, 'Encaixa estudo e empurra a academia');
        unawaited(cubit.close());
      });
    });

    test('take hands over the text and how long it took to say', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer.say('O que tenho amanhã?');
        async.elapse(const Duration(seconds: 11));

        VoiceTake? take;
        unawaited(cubit.take().then((value) => take = value));
        async.flushMicrotasks();

        expect(
          take,
          const VoiceTake(
            text: 'O que tenho amanhã?',
            length: Duration(seconds: 11),
          ),
        );
        expect(recognizer.stops, 1);
        expect(cubit.state.status, VoiceStatus.idle);
        unawaited(cubit.close());
      });
    });

    test('take with nothing said hands over nothing', () {
      _onFakeTime((async) {
        final cubit = VoiceCubit(recognizer: _FakeRecognizer());

        unawaited(cubit.start());
        async.flushMicrotasks();

        var taken = true;
        unawaited(cubit.take().then((value) => taken = value != null));
        async.flushMicrotasks();

        expect(taken, isFalse);
        unawaited(cubit.close());
      });
    });

    test('stops hearing at a minute and holds the words', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer.say('Uma lista bem longa');
        async.elapse(const Duration(seconds: 61));

        expect(cubit.state.status, VoiceStatus.stopped);
        expect(cubit.state.elapsed, VoiceCubit.limit);
        expect(cubit.state.heard, 'Uma lista bem longa');
        expect(recognizer.stops, 1);

        VoiceTake? take;
        unawaited(cubit.take().then((value) => take = value));
        async.flushMicrotasks();
        expect(take?.length, VoiceCubit.limit);
        unawaited(cubit.close());
      });
    });

    test('dictation has no limit', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = DictationCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer.say('Um ditado comprido');
        async.elapse(const Duration(minutes: 5));

        expect(cubit.state.status, VoiceStatus.listening);
        expect(cubit.state.elapsed, const Duration(minutes: 5));
        expect(recognizer.stops, 0);
        unawaited(cubit.close());
      });
    });

    test('cancel drops everything', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer.say('Esquece');
        unawaited(cubit.cancel());
        async.flushMicrotasks();

        expect(cubit.state, const VoiceState());
        expect(recognizer.cancels, 1);

        // A late word from the dropped session changes nothing.
        recognizer.say('Esquece isso');
        expect(cubit.state, const VoiceState());
        unawaited(cubit.close());
      });
    });

    test('says when the microphone was refused or is not there', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer(VoiceAvailability.denied);
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        expect(cubit.state.status, VoiceStatus.denied);
        expect(cubit.state.status.offered, isFalse);
        expect(recognizer.sessions, 0);

        recognizer.availability = VoiceAvailability.unavailable;
        unawaited(cubit.start());
        async.flushMicrotasks();
        expect(cubit.state.status, VoiceStatus.unavailable);
        unawaited(cubit.close());
      });
    });

    test('draws the level against the quietest and loudest heard', () {
      _onFakeTime((async) {
        final recognizer = _FakeRecognizer();
        final cubit = VoiceCubit(recognizer: recognizer);

        unawaited(cubit.start());
        async.flushMicrotasks();
        recognizer
          ..level(-2)
          ..level(10)
          ..level(4);

        expect(cubit.state.levels, [0, 1, 0.5]);

        for (var i = 0; i < 40; i++) {
          recognizer.level(i.toDouble());
        }
        expect(cubit.state.levels, hasLength(VoiceCubit.bars));
        unawaited(cubit.close());
      });
    });
  });

  group('AgentSheet', () {
    setUpAll(() => registerFallbackValue(<AgentEntry>[]));

    Future<(_FakeRecognizer, AgentCubit, VoiceCubit)> pumpSheet(
      WidgetTester tester, {
      bool recording = false,
      String? draft,
    }) async {
      final repository = _answering();
      final recognizer = _FakeRecognizer();
      final agent = AgentCubit(repository: repository);
      // Made in the tree, so it is closed with it.
      late VoiceCubit voice;

      await tester.pumpWidget(
        _app(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: agent),
              BlocProvider(
                create: (_) => voice = VoiceCubit(recognizer: recognizer),
                lazy: false,
              ),
            ],
            child: Scaffold(body: AgentSheet(draft: draft)),
          ),
        ),
      );
      // A recording begun on Tempo's bar, as the sheet opened.
      if (recording) await voice.start();
      await tester.pump();

      return (recognizer, agent, voice);
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    testWidgets('opens empty, on the field', (tester) async {
      await pumpSheet(tester);

      expect(field(tester).focusNode!.hasFocus, isTrue);
      expect(field(tester).controller!.text, isEmpty);
    });

    testWidgets('opens with a draft in the field, selected', (tester) async {
      await pumpSheet(tester, draft: 'Encaixa estudo');

      final controller = field(tester).controller!;
      expect(controller.text, 'Encaixa estudo');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 14),
      );
      expect(field(tester).focusNode!.hasFocus, isTrue);
    });

    testWidgets('stopping sends what was said, at once', (tester) async {
      final (recognizer, agent, _) = await pumpSheet(tester);

      await tester.tap(find.bySemanticsLabel('Falar'));
      await tester.pump();
      expect(
        find.text('Pode falar. Eu escrevo enquanto você fala.'),
        findsOneWidget,
      );

      recognizer.say('O que tenho amanhã?');
      await tester.pump();
      expect(find.textContaining('O que tenho amanhã?'), findsOneWidget);

      // The recorder's stop is the composer's send: one tap, not two.
      await tester.tap(find.bySemanticsLabel('Enviar'));
      await tester.pumpAndSettle();

      expect(recognizer.stops, 1);
      final said = agent.state.entries.first as UserEntry;
      expect(said.text, 'O que tenho amanhã?');
      expect(said.voice, isNotNull);
      expect(find.text('por voz · 0:00'), findsOneWidget);
      expect(field(tester).controller!.text, isEmpty);
    });

    testWidgets('held, letting go sends what was said', (tester) async {
      final (recognizer, agent, _) = await pumpSheet(tester);

      final finger = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Falar')),
      );
      await tester.pump();
      recognizer.say('Encaixa estudo');
      await tester.pump(VoiceHold.hold);
      await finger.up();
      await tester.pump();
      await tester.pump();

      expect(recognizer.stops, 1);
      final said = agent.state.entries.first as UserEntry;
      expect(said.text, 'Encaixa estudo');
      expect(said.voice, isNotNull);
      expect(field(tester).controller!.text, isEmpty);
    });

    testWidgets('a recording begun on Tempo carries on in the sheet', (
      tester,
    ) async {
      final (recognizer, _, voice) = await pumpSheet(tester, recording: true);
      recognizer.say('Encaixa estudo');
      await tester.pump();

      expect(recognizer.sessions, 1);
      expect(voice.state.status, VoiceStatus.listening);
      expect(find.textContaining('Encaixa estudo'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('discarding leaves nothing behind', (tester) async {
      final (recognizer, agent, _) = await pumpSheet(tester, recording: true);
      recognizer.say('Esquece');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Descartar'));
      await tester.pumpAndSettle();

      expect(recognizer.cancels, 1);
      expect(field(tester).controller!.text, isEmpty);
      expect(agent.state.entries, isEmpty);
    });

    testWidgets('a refused microphone says so and is no longer offered', (
      tester,
    ) async {
      final (recognizer, _, _) = await pumpSheet(tester);
      recognizer.availability = VoiceAvailability.denied;

      await tester.tap(find.bySemanticsLabel('Falar'));
      await tester.pump();

      expect(
        find.textContaining('não tem acesso ao microfone'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Falar'), findsNothing);
    });
  });

  group('AskDock', () {
    setUpAll(() {
      registerFallbackValue(<AgentEntry>[]);
      registerFallbackValue(const TimelineRequested());
    });

    Future<(_FakeRecognizer, VoiceCubit)> pumpDock(WidgetTester tester) async {
      final repository = _answering();
      final recognizer = _FakeRecognizer();
      late VoiceCubit voice;
      final timeline = _MockTimelineBloc();
      when(() => timeline.state).thenReturn(const TimelineState());

      await tester.pumpWidget(
        RepositoryProvider<AgentRepository>.value(
          value: repository,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => AgentCubit(repository: repository)),
              BlocProvider<TimelineBloc>.value(value: timeline),
              BlocProvider(
                create: (_) => voice = VoiceCubit(recognizer: recognizer),
                lazy: false,
              ),
            ],
            child: _app(
              const Scaffold(
                floatingActionButton: AskDock(
                  fab: SizedBox.square(key: Key('fab'), dimension: 56),
                ),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.centerFloat,
              ),
            ),
          ),
        ),
      );
      return (recognizer, voice);
    }

    /// Lets the dock and the sheet move, which never settle while the
    /// recording's dot breathes.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> record(WidgetTester tester, _FakeRecognizer recognizer) async {
      await tester.tap(find.bySemanticsLabel('Falar'));
      await settle(tester);
      recognizer.say('Encaixa estudo amanhã');
      await tester.pump();
    }

    testWidgets('the microphone records on the spot, no sheet', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);

      await record(tester, recognizer);

      expect(voice.state.status, VoiceStatus.listening);
      expect(find.byType(AgentSheet), findsNothing);
      expect(find.byType(AskBar), findsNothing);
      expect(find.byType(VoiceBar), findsOneWidget);
      expect(find.textContaining('Encaixa estudo amanhã'), findsOneWidget);
      expect(find.text('Ouvindo'), findsOneWidget);
    });

    Future<TestGesture> hold(
      WidgetTester tester,
      _FakeRecognizer recognizer,
    ) async {
      final finger = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Falar')),
      );
      await tester.pump();
      await tester.pump(VoiceHold.hold);
      recognizer.say('Encaixa estudo amanhã');
      await tester.pump();
      return finger;
    }

    bool held(WidgetTester tester) =>
        tester.widget<AskRecorder>(find.byType(AskRecorder)).held;

    testWidgets('held, letting go sends: the conversation opens on it', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);

      final finger = await hold(tester, recognizer);
      // Recording as the finger lands, the bar the held recorder.
      expect(voice.state.status, VoiceStatus.listening);
      expect(held(tester), isTrue);
      expect(find.text('Deslize para cancelar'), findsOneWidget);

      await finger.up();
      await settle(tester);

      expect(recognizer.stops, 1);
      expect(find.byType(AgentSheet), findsOneWidget);
      final agent = tester.element(find.byType(AgentSheet)).read<AgentCubit>();
      final said = agent.state.entries.first as UserEntry;
      expect(said.text, 'Encaixa estudo amanhã');
      expect(said.voice, isNotNull);
    });

    testWidgets('held, sliding left drops the recording', (tester) async {
      final (recognizer, voice) = await pumpDock(tester);

      final finger = await hold(tester, recognizer);
      await finger.moveBy(const Offset(-120, 0));
      await tester.pump();
      await finger.up();
      await settle(tester);

      expect(recognizer.cancels, 1);
      expect(voice.state.status, VoiceStatus.idle);
      expect(find.byType(AgentSheet), findsNothing);
      expect(find.byType(AskBar), findsOneWidget);
    });

    testWidgets('held, sliding up locks it on without the finger', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);

      final finger = await hold(tester, recognizer);
      await finger.moveBy(const Offset(0, -100));
      await tester.pump();
      await finger.up();
      await settle(tester);

      expect(voice.state.status, VoiceStatus.listening);
      expect(recognizer.stops + recognizer.cancels, 0);
      expect(find.byType(AgentSheet), findsNothing);
      expect(held(tester), isFalse);
      expect(find.byType(VoiceBar), findsOneWidget);
    });

    testWidgets('a quick tap keeps recording after the finger leaves', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);

      await record(tester, recognizer);
      await settle(tester);

      expect(voice.state.status, VoiceStatus.listening);
      expect(recognizer.stops + recognizer.cancels, 0);
      expect(find.byType(AgentSheet), findsNothing);
    });

    testWidgets('send, where the + was, sends what was said', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);
      await record(tester, recognizer);

      await tester.tap(find.byTooltip('Enviar'));
      await settle(tester);

      expect(voice.state.status, VoiceStatus.idle);
      expect(find.byType(AgentSheet), findsOneWidget);
      final agent = tester.element(find.byType(AgentSheet)).read<AgentCubit>();
      expect(
        (agent.state.entries.first as UserEntry).text,
        'Encaixa estudo amanhã',
      );
    });

    testWidgets('send sits centre on centre where the + was', (tester) async {
      final (recognizer, _) = await pumpDock(tester);
      final plus = tester.getCenter(find.byKey(const Key('fab')));
      final dock = tester.getRect(find.byType(AskDock));
      await record(tester, recognizer);

      final send = tester.getCenter(find.byTooltip('Enviar'));
      expect((send - plus).distance, lessThan(1.5));
      // One surface, as wide as the bar and the + were, growing upward.
      final panel = tester.getRect(find.byType(AskRecorder));
      expect(panel.left, moreOrLessEquals(dock.left));
      expect(panel.right, moreOrLessEquals(dock.right));
      expect(panel.bottom, moreOrLessEquals(dock.bottom, epsilon: 1));
    });

    testWidgets('held, the microphone swells under the finger', (
      tester,
    ) async {
      final (recognizer, _) = await pumpDock(tester);
      final mic = tester.getCenter(find.bySemanticsLabel('Falar'));
      final finger = await hold(tester, recognizer);

      final swollen = tester.getCenter(
        find.descendant(
          of: find.byType(AskRecorder),
          matching: find.byWidgetPredicate(
            (it) => it is AppIcon && it.iconData == AppIcons.microphone,
          ),
        ),
      );
      expect((swollen - mic).distance, lessThan(2));

      await finger.up();
      await settle(tester);
    });

    testWidgets('discard brings the bar and the + back', (tester) async {
      final (recognizer, voice) = await pumpDock(tester);
      await record(tester, recognizer);

      await tester.tap(find.bySemanticsLabel('Descartar'));
      await tester.pumpAndSettle();

      expect(recognizer.cancels, 1);
      expect(voice.state.status, VoiceStatus.idle);
      expect(find.byType(AskBar), findsOneWidget);
      expect(find.byType(VoiceBar), findsNothing);
    });

    testWidgets('the words open the conversation with them in the field', (
      tester,
    ) async {
      final (recognizer, voice) = await pumpDock(tester);
      await record(tester, recognizer);

      await tester.tap(find.bySemanticsLabel(RegExp('^Abrir a conversa')));
      await settle(tester);

      expect(find.byType(AgentSheet), findsOneWidget);
      expect(voice.state.status, VoiceStatus.idle);
      final agent = tester.element(find.byType(AgentSheet)).read<AgentCubit>();
      expect(agent.state.entries, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Encaixa estudo amanhã',
      );
    });

    testWidgets('at the limit it says it stopped listening', (tester) async {
      final (recognizer, _) = await pumpDock(tester);
      await record(tester, recognizer);

      await tester.pump(VoiceCubit.limit);
      await tester.pump();

      expect(find.text('Parei de ouvir no limite de 1 minuto'), findsOneWidget);
      expect(find.byType(VoiceBar), findsOneWidget);
    });

    testWidgets('a refused microphone opens the conversation, saying why', (
      tester,
    ) async {
      final (recognizer, _) = await pumpDock(tester);
      recognizer.availability = VoiceAvailability.denied;

      await tester.tap(find.bySemanticsLabel('Falar'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentSheet), findsOneWidget);
      expect(
        find.textContaining('não tem acesso ao microfone'),
        findsOneWidget,
      );
    });
  });

  group('LiveTextController', () {
    testWidgets('draws the words still open to revision in ink3', (
      tester,
    ) async {
      final notes = LiveTextController(text: 'Pão');
      await tester.pumpWidget(
        _app(Scaffold(body: TextField(controller: notes))),
      );

      notes.write(
        'Pão\n\nLevar sacolas',
        live: const TextRange(start: 11, end: 18),
      );
      await tester.pump();
      final span = notes.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );
      final parts = span.children!.cast<TextSpan>();
      expect(parts.map((it) => it.text), ['Pão\n\nLevar ', 'sacolas', '']);
      expect(parts[1].style?.color, AppColors.ink3);
      expect(notes.selection, const TextSelection.collapsed(offset: 18));

      notes.settle();
      expect(notes.live, isNull);
      expect(
        notes
            .buildTextSpan(
              context: tester.element(find.byType(TextField)),
              withComposing: false,
            )
            .children,
        isNull,
      );
    });
  });

  group('NotesDock', () {
    setUpAll(() {
      registerFallbackValue(<AgentEntry>[]);
      registerFallbackValue(const TimelineRequested());
    });

    late AgentRepository repository;
    late _FakeRecognizer recognizer;
    late VoiceCubit asking;
    late LiveTextController notes;

    Future<void> pumpDock(WidgetTester tester) async {
      repository = _answering();
      recognizer = _FakeRecognizer();
      notes = LiveTextController(text: 'Comprar pão');
      addTearDown(notes.dispose);
      final timeline = _MockTimelineBloc();
      when(() => timeline.state).thenReturn(const TimelineState());

      await tester.pumpWidget(
        RepositoryProvider<AgentRepository>.value(
          value: repository,
          child: RepositoryProvider<VoiceRecognizer>.value(
            value: recognizer,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => AgentCubit(repository: repository),
                ),
                BlocProvider<TimelineBloc>.value(value: timeline),
                BlocProvider(
                  create: (_) => asking = VoiceCubit(recognizer: recognizer),
                  lazy: false,
                ),
              ],
              child: _app(
                Scaffold(
                  body: Stack(
                    children: [
                      TextField(controller: notes, maxLines: null),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: NotesDock(
                          notes: notes,
                          about: const AgentSubject.task('t1'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> dictate(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ditar nas anotações'));
      await settle(tester);
    }

    testWidgets('writes the words into the notes as a new paragraph', (
      tester,
    ) async {
      await pumpDock(tester);
      await dictate(tester);
      expect(find.byType(VoiceBar), findsOneWidget);

      recognizer.say('Levar sacolas');
      await tester.pump();
      expect(notes.text, 'Comprar pão\n\nLevar sacolas');
      expect(notes.live, const TextRange(start: 13, end: 26));

      recognizer.say('Levar sacolas', done: true);
      await tester.pump();
      expect(notes.live, isNull);

      await tester.tap(find.bySemanticsLabel('Parar de ditar'));
      await settle(tester);
      expect(notes.text, 'Comprar pão\n\nLevar sacolas');
      expect(notes.live, isNull);
      expect(find.byType(VoiceBar), findsNothing);
      expect(find.byTooltip('Ditar nas anotações'), findsOneWidget);
    });

    testWidgets('stop keeps the words still being heard', (tester) async {
      await pumpDock(tester);
      await dictate(tester);
      recognizer.say('Ligar para');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Parar de ditar'));
      await settle(tester);
      expect(notes.text, 'Comprar pão\n\nLigar para');
      expect(notes.live, isNull);
      expect(recognizer.stops, 1);
    });

    testWidgets('a session the platform ends carries on the same paragraph', (
      tester,
    ) async {
      await pumpDock(tester);
      await dictate(tester);
      recognizer.say('Levar');
      await tester.pump();

      recognizer.end();
      await tester.pump();
      recognizer.say('sacolas');
      await tester.pump();

      expect(recognizer.sessions, 2);
      expect(notes.text, 'Comprar pão\n\nLevar sacolas');
    });

    testWidgets('discarding takes the paragraph back out', (tester) async {
      await pumpDock(tester);
      await dictate(tester);
      recognizer.say('Isto não');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Descartar este parágrafo'));
      await settle(tester);
      expect(notes.text, 'Comprar pão');
      expect(notes.live, isNull);
      expect(recognizer.cancels, 1);
    });

    testWidgets('a refused microphone says why', (tester) async {
      await pumpDock(tester);
      recognizer.availability = VoiceAvailability.denied;

      await dictate(tester);
      expect(
        find.textContaining('não tem acesso ao microfone'),
        findsOneWidget,
      );
      expect(notes.text, 'Comprar pão');
      expect(find.byType(VoiceBar), findsNothing);
    });

    testWidgets('the agent taking the microphone stops dictation, keeping it', (
      tester,
    ) async {
      await pumpDock(tester);
      await dictate(tester);
      recognizer.say('Levar sacolas');
      await tester.pump();

      await asking.start();
      await settle(tester);
      expect(notes.text, 'Comprar pão\n\nLevar sacolas');
      expect(notes.live, isNull);
      expect(asking.state.status, VoiceStatus.listening);
    });

    testWidgets('stays put while the keyboard is up', (tester) async {
      await pumpDock(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      expect(find.byTooltip('Ditar nas anotações'), findsOneWidget);
    });

    testWidgets('while typing, writes the paragraph at the cursor', (
      tester,
    ) async {
      await pumpDock(tester);
      notes.notes = 'Comprar pão\nLevar lixo';
      await tester.showKeyboard(find.byType(TextField));
      notes.selection = const TextSelection.collapsed(offset: 11);
      await tester.pump();

      await dictate(tester);
      recognizer.say('Ligar para a Ana');
      await tester.pump();

      expect(notes.text, 'Comprar pão\n\nLigar para a Ana\n\nLevar lixo');
      expect(notes.selection.baseOffset, 29);
    });

    testWidgets('the conversation it opens is about the page', (tester) async {
      await pumpDock(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('Pergunte')));
      await tester.pumpAndSettle();
      expect(find.byType(AgentSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AgentSheet),
          matching: find.byType(TextField),
        ),
        'Resume isso',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enviar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.turn(
          any(),
          conversationId: any(named: 'conversationId'),
          day: any(named: 'day'),
          about: const AgentSubject.task('t1'),
        ),
      ).called(1);
    });
  });
}

void _suggestionCardTests() {
  group('SuggestionCard', () {
    setUpAll(() {
      registerFallbackValue(<AgentEntry>[]);
      registerFallbackValue(const TimelineRequested());
    });

    const plan = AgentPlan(
      id: 'p1',
      changes: [
        PlanChange(
          kind: PlanChangeKind.moveTask,
          title: 'Escrever a leitura',
          minutes: 120,
        ),
      ],
    );

    Future<void> pumpCard(WidgetTester tester, AgentSuggestion offered) async {
      final repository = _answering();
      when(repository.suggestion).thenAnswer((_) async => offered);
      final timeline = _MockTimelineBloc();
      when(() => timeline.state).thenReturn(const TimelineState());
      final suggestions = SuggestionCubit(repository: repository);
      await suggestions.load();

      await tester.pumpWidget(
        RepositoryProvider<AgentRepository>.value(
          value: repository,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => AgentCubit(repository: repository)),
              BlocProvider<TimelineBloc>.value(value: timeline),
              BlocProvider(
                create: (_) => VoiceCubit(recognizer: _FakeRecognizer()),
              ),
              BlocProvider.value(value: suggestions),
            ],
            child: _app(const Scaffold(body: SuggestionCard())),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('about the goal, it only talks', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(
        tester,
        AgentSuggestion(
          id: 's1',
          text: 'Você ainda não tem um objetivo.',
          focus: SuggestionFocus.goal,
          validUntil: DateTime(2100),
        ),
      );

      expect(find.text('Objetivo'), findsOneWidget);
      expect(find.text('Conversar'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('with an action, Conversar opens the page on its opening, '
        'plan and all', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(
        tester,
        AgentSuggestion(
          id: 's1',
          text: 'Encaixo hoje às 14:00?',
          focus: SuggestionFocus.delivery,
          validUntil: DateTime(2100),
          action: const SuggestionAction(
            label: 'Encaixar às 14:00',
            plan: plan,
          ),
          opening: const AgentReply(
            text: 'Faltam R\$ 2.400.',
            plan: plan,
            blocks: [CaptionBlock('Faltam R\$ 2.400.'), PlanBlock()],
          ),
        ),
      );

      expect(find.text('Encaixar às 14:00'), findsOneWidget);
      await tester.tap(find.text('Conversar'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentSheet), findsOneWidget);
      expect(find.text('Faltam R\$ 2.400.'), findsOneWidget);
      expect(find.text('Escrever a leitura'), findsWidgets);
    });
  });
}

AgentRepository _answering() {
  final repository = _MockRepository();
  when(
    () => repository.turn(
      any(),
      conversationId: any(named: 'conversationId'),
      day: any(named: 'day'),
      about: any(named: 'about'),
    ),
  ).thenAnswer(
    (_) async =>
        (conversationId: 'c1', reply: const AgentReply(text: 'Pronto.')),
  );
  when(
    () => repository.conversations(before: any(named: 'before')),
  ).thenAnswer((_) async => []);
  return repository;
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.current,
  home: home,
);
