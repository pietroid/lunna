import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayLabel', () {
    final today = DateTime(2026, 9, 24, 15);

    test('names today and tomorrow, and writes out the rest', () {
      expect(
        AppWheelPicker.dayLabel(DateTime(2026, 9, 24), now: today),
        'Hoje',
      );
      expect(
        AppWheelPicker.dayLabel(DateTime(2026, 9, 25), now: today),
        'Amanhã',
      );
      expect(
        AppWheelPicker.dayLabel(DateTime(2026, 10, 2), now: today),
        'sex, 2 out',
      );
    });
  });

  testWidgets('opened on an hour, it is fixed there with the day to change', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 3));
    final at = DateTime(start.year, start.month, start.day, 20);
    AppPromptResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
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

    expect(find.text(AppWheelPicker.dayLabel(at)), findsOneWidget);
    expect(find.text('20:00–20:30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Jantar');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(result?.fixed, isTrue);
    expect(result?.startTime, at);
  });

  testWidgets('switched to flexible, it goes to where it would land', (
    tester,
  ) async {
    final today = DateTime.now().add(const Duration(days: 2));
    final room = DateTime(today.year, today.month, today.day, 14, 5);
    final fixedAt = DateTime(today.year, today.month, today.day, 16);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppPromptSheet.show(
                context,
                // Where the room starts, as the timeline would work it out.
                previewFor: (_) => room,
                initialStart: fixedAt,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('16:00–16:30'), findsOneWidget);

    await tester.tap(find.text('Flexível'));
    await tester.pumpAndSettle();

    expect(find.textContaining('14:05'), findsOneWidget);
    expect(find.text('16:00–16:30'), findsNothing);
  });
}
