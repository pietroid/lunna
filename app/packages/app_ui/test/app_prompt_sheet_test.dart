import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

final AppLocalizations l10n = lookupAppLocalizations(const Locale('pt'));

void main() {
  group('dayLabel', () {
    final today = DateTime(2026, 9, 24, 15);

    test('names today and tomorrow, and writes out the rest', () {
      expect(
        AppWheelPicker.dayLabel(l10n, DateTime(2026, 9, 24), now: today),
        'Hoje',
      );
      expect(
        AppWheelPicker.dayLabel(l10n, DateTime(2026, 9, 25), now: today),
        'Amanhã',
      );
      expect(
        AppWheelPicker.dayLabel(l10n, DateTime(2026, 10, 2), now: today),
        'sex, 2 out',
      );
    });
  });

  testWidgets('opened on an hour, it is flexible there, the day to change', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 3));
    final at = DateTime(start.year, start.month, start.day, 20);
    AppPromptResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await AppPromptSheet.show(
                context,
                previewFor: (_) => DateTime.now(),
                initialStart: at,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text(AppWheelPicker.dayLabel(l10n, at)), findsOneWidget);
    expect(find.text('20:00–20:30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Jantar');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(result?.fixed, isFalse);
    expect(result?.startTime, at);
  });

  testWidgets('switched to fixed, it keeps the hour it was opened on', (
    tester,
  ) async {
    final today = DateTime.now().add(const Duration(days: 2));
    final room = DateTime(today.year, today.month, today.day, 14, 5);
    final at = DateTime(today.year, today.month, today.day, 16);
    AppPromptResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await AppPromptSheet.show(
                context,
                previewFor: (_) => room,
                initialStart: at,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fixo'));
    await tester.pumpAndSettle();
    expect(find.text('16:00–16:30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Dentista');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(result?.fixed, isTrue);
    expect(result?.startTime, at);
  });

  testWidgets('without an hour, it reads where it goes and offers one', (
    tester,
  ) async {
    final today = DateTime.now().add(const Duration(days: 2));
    final room = DateTime(today.year, today.month, today.day, 14, 5);
    AppPromptResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await AppPromptSheet.show(
                context,
                previewFor: (_) => room,
                flexibleLabel: 'Na fila',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Na fila'), findsOneWidget);
    expect(find.text(l10n.promptPickTime), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ler');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(result?.fixed, isFalse);
    expect(result?.startTime, isNull);
  });
}
