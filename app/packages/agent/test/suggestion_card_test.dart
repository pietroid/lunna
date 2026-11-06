import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AgentRepository {}

const _plan = AgentPlan(id: 'p1', changes: []);

const _action = SuggestionAction(label: 'Aplicar', plan: _plan);

AgentSuggestion _suggestion({SuggestionAction? action, String? text}) =>
    AgentSuggestion(
      id: 's1',
      text: text ?? 'Encaixe a revisão hoje. Sobram 2 horas antes do almoço.',
      nextAt: DateTime(2026, 10, 16, 9),
      action: action,
    );

Widget _app(Widget child, SuggestionCubit cubit) => MaterialApp(
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.current,
  home: Scaffold(
    body: BlocProvider<SuggestionCubit>.value(value: cubit, child: child),
  ),
);

void main() {
  late AgentRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.dismissSuggestion(any())).thenAnswer((_) async {});
  });

  Future<SuggestionCubit> loaded(AgentSuggestion suggestion) async {
    when(() => repository.suggestion()).thenAnswer((_) async => suggestion);
    final cubit = SuggestionCubit(repository: repository);
    await cubit.load();
    return cubit;
  }

  group('SuggestionCard', () {
    testWidgets('shows the title, the description and the three actions', (
      tester,
    ) async {
      final cubit = await loaded(_suggestion(action: _action));

      await tester.pumpWidget(_app(const SuggestionCard(), cubit));

      expect(find.text('Encaixe a revisão hoje'), findsOneWidget);
      expect(find.text('Sobram 2 horas antes do almoço.'), findsOneWidget);
      expect(find.text('Aceitar'), findsOneWidget);
      expect(find.text('Ajustar'), findsOneWidget);
      expect(find.text('Agora não'), findsOneWidget);
    });

    testWidgets('the three actions are in order Aceitar, Agora não, Ajustar', (
      tester,
    ) async {
      final cubit = await loaded(_suggestion(action: _action));

      await tester.pumpWidget(_app(const SuggestionCard(), cubit));

      final aceitar = tester.getTopLeft(find.text('Aceitar')).dx;
      final agoraNao = tester.getTopLeft(find.text('Agora não')).dx;
      final ajustar = tester.getTopLeft(find.text('Ajustar')).dx;
      expect(aceitar, lessThan(agoraNao));
      expect(agoraNao, lessThan(ajustar));
    });

    testWidgets('accepting draws the spinner in Aceitar’s place', (
      tester,
    ) async {
      final cubit = await loaded(_suggestion(action: _action));

      await tester.pumpWidget(
        _app(const SuggestionCard(accepting: true), cubit),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Aceitar'), findsNothing);
    });

    testWidgets('the ✕ tells the server, and the card goes', (tester) async {
      final cubit = await loaded(_suggestion(action: _action));

      await tester.pumpWidget(_app(const SuggestionCard(), cubit));

      await tester.tap(find.text('Agora não'));
      await tester.pump();

      verify(() => repository.dismissSuggestion('s1')).called(1);
      expect(cubit.state, isNull);
    });

    testWidgets('no plan: Ajustar and Agora não, but no Aceitar', (
      tester,
    ) async {
      final cubit = await loaded(_suggestion(text: 'Quer encaixar?'));

      await tester.pumpWidget(_app(const SuggestionCard(), cubit));

      expect(find.text('Ajustar'), findsOneWidget);
      expect(find.text('Agora não'), findsOneWidget);
      expect(find.text('Aceitar'), findsNothing);
    });
  });

  group('suggestionWords', () {
    test('one sentence: no description', () {
      expect(suggestionWords('Uma frase só.'), ('Uma frase só', ''));
    });

    test('two sentences: the first is the title, the rest the description',
        () {
      expect(
        suggestionWords('Encaixe a revisão hoje. Sobram 2 horas.'),
        ('Encaixe a revisão hoje', 'Sobram 2 horas.'),
      );
    });
  });
}
