import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.current,
  home: Scaffold(body: home),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('pt'));

  group('ComposeCubit', () {
    test('sends the field and holds what it was read as', () async {
      final cubit = ComposeCubit(
        read: (text) async => ComposeDraft(kind: ComposeKind.task, title: text),
      )..edit('  Responder e-mails ');

      await cubit.send();

      expect(cubit.state.status, ComposeStatus.ready);
      expect(cubit.state.draft?.title, 'Responder e-mails');
      await cubit.close();
    });

    test('a read that comes back after an edit is dropped', () async {
      final answer = Completer<ComposeDraft>();
      final cubit = ComposeCubit(read: (_) => answer.future)..edit('Dentista');

      final sent = cubit.send();
      cubit.edit('Dentista amanhã');
      answer.complete(
        const ComposeDraft(kind: ComposeKind.event, title: 'Dentista'),
      );
      await sent;

      expect(cubit.state.status, ComposeStatus.editing);
      expect(cubit.state.draft, isNull);
      await cubit.close();
    });

    test('a failed read keeps the words, to send again', () async {
      final cubit = ComposeCubit(read: (_) => Future.error(Exception('down')))
        ..edit('Ligar para a Ana');

      await cubit.send();

      expect(cubit.state.status, ComposeStatus.failed);
      expect(cubit.state.text, 'Ligar para a Ana');
      await cubit.close();
    });
  });

  test('reads the server’s draft', () {
    final draft = ComposeDraft.fromJson(const {
      'kind': 'task',
      'title': 'Vídeo',
      'minutes': 90,
      'parent': {'id': 'p1', 'title': 'Post: Lua cheia'},
      'subtasks': [
        {'title': 'Roteiro'},
        {'title': 'Gravar', 'minutes': 30},
      ],
      'changes': <String>[],
    });

    expect(draft.kind, ComposeKind.task);
    expect(draft.parent, 'Post: Lua cheia');
    expect(draft.parentId, 'p1');
    expect(draft.subtasks, const [
      ComposeSubtask('Roteiro'),
      ComposeSubtask('Gravar', minutes: 30),
    ]);
    expect(
      ComposeDraft.fromJson(const {'kind': 'surprise', 'title': 'x'}).kind,
      ComposeKind.plan,
    );
  });

  group('ComposeSummary', () {
    testWidgets('says a goal by its amount and its day', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 3, 10)), () async {
        await tester.pumpWidget(
          _app(
            ComposeSummary(
              state: ComposeState(
                status: ComposeStatus.ready,
                text: '10 mil até 30/11',
                draft: ComposeDraft(
                  kind: ComposeKind.goal,
                  title: 'Novembro',
                  value: 10000,
                  due: DateTime(2026, 11, 30),
                ),
              ),
            ),
          ),
        );
      });

      expect(
        find.text(
          '${l10n.composeKindGoal} · '
          '${l10n.composeGoalBy(r'R$ 10.000', '30/11')}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.composeAdd), findsOneWidget);
    });

    testWidgets('a turn that proposed nothing offers only the conversation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ComposeSummary(
            state: ComposeState(
              status: ComposeStatus.ready,
              text: 'como está meu dia?',
              draft: ComposeDraft(
                kind: ComposeKind.plan,
                title: 'Seu dia está tranquilo.',
                conversationId: 'c1',
              ),
            ),
          ),
        ),
      );

      expect(find.text(l10n.composeTalk), findsOneWidget);
      expect(find.text(l10n.composeApply), findsNothing);
    });

    testWidgets('a failed read says so', (tester) async {
      await tester.pumpWidget(
        _app(
          const ComposeSummary(
            state: ComposeState(status: ComposeStatus.failed, text: 'x'),
          ),
        ),
      );

      expect(find.text(l10n.composeFailed), findsOneWidget);
    });
  });
}
