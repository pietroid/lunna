import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

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

final _now = DateTime(2026, 10, 15, 9, 41);

/// Runs [body] on a clock and timers the test moves by hand.
void _onFakeTime(void Function(FakeAsync async) body) {
  fakeAsync((async) {
    withClock(async.getClock(_now), () => body(async));
  });
}

void main() {
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

    Future<(_FakeRecognizer, AgentCubit)> pumpSheet(
      WidgetTester tester, {
      bool listen = false,
    }) async {
      final repository = _MockRepository();
      when(
        () => repository.turn(
          any(),
          conversationId: any(named: 'conversationId'),
          day: any(named: 'day'),
        ),
      ).thenAnswer(
        (_) async =>
            (conversationId: 'c1', reply: const AgentReply(text: 'Pronto.')),
      );
      when(
        () => repository.conversations(before: any(named: 'before')),
      ).thenAnswer((_) async => []);
      final recognizer = _FakeRecognizer();
      final agent = AgentCubit(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.current,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: agent),
                BlocProvider(
                  create: (_) => VoiceCubit(recognizer: recognizer),
                ),
              ],
              child: AgentSheet(listen: listen),
            ),
          ),
        ),
      );
      await tester.pump();

      return (recognizer, agent);
    }

    testWidgets('the microphone records into the composer and sends', (
      tester,
    ) async {
      final (recognizer, agent) = await pumpSheet(tester);

      await tester.tap(find.bySemanticsLabel('Falar'));
      await tester.pump();
      expect(find.text('Ouvindo'), findsOneWidget);
      expect(
        find.text('Pode falar. Eu escrevo enquanto você fala.'),
        findsOneWidget,
      );

      recognizer.say('O que tenho amanhã?');
      await tester.pump();
      expect(find.textContaining('O que tenho amanhã?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Enviar'));
      await tester.pumpAndSettle();

      final said = agent.state.entries.first as UserEntry;
      expect(said.text, 'O que tenho amanhã?');
      expect(said.voice, isNotNull);
      expect(find.text('por voz · 0:00'), findsOneWidget);
      expect(find.text('Ouvindo'), findsNothing);
    });

    testWidgets('opens recording when asked to', (tester) async {
      final (recognizer, _) = await pumpSheet(tester, listen: true);
      await tester.pump();

      expect(recognizer.sessions, 1);
      expect(find.text('Ouvindo'), findsOneWidget);
    });

    testWidgets('tapping the words hands them to the keyboard', (
      tester,
    ) async {
      final (recognizer, agent) = await pumpSheet(tester, listen: true);
      await tester.pump();
      recognizer.say('Encaixa estudo');
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.textContaining('Encaixa estudo', findRichText: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ouvindo'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Encaixa estudo');
      expect(agent.state.entries, isEmpty);
    });

    testWidgets('discarding leaves nothing behind', (tester) async {
      final (recognizer, agent) = await pumpSheet(tester, listen: true);
      await tester.pump();
      recognizer.say('Esquece');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Descartar'));
      await tester.pumpAndSettle();

      expect(recognizer.cancels, 1);
      expect(find.text('Ouvindo'), findsNothing);
      expect(agent.state.entries, isEmpty);
    });

    testWidgets('a refused microphone says so and is no longer offered', (
      tester,
    ) async {
      final (recognizer, _) = await pumpSheet(tester);
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
}
