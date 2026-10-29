import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTitleTabs', () {
    Future<List<int>> pump(WidgetTester tester, {Widget? trailing}) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          home: Scaffold(
            body: AppTitleTabs(
              labels: const ['Tarefas', 'Entregas', 'Objetivos'],
              selected: 1,
              onSelected: tapped.add,
              trailing: trailing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tapped;
    }

    Color? colorOf(WidgetTester tester, String label) => tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style
        .color;

    testWidgets('draws the word in front in ink and the others quiet', (
      tester,
    ) async {
      await pump(tester);

      expect(colorOf(tester, 'Entregas'), AppColors.ink);
      expect(colorOf(tester, 'Tarefas'), AppColors.ink3);
      expect(colorOf(tester, 'Objetivos'), AppColors.ink3);
      expect(
        tester.getSemantics(find.text('Entregas')),
        containsSemantics(isSelected: true, isButton: true),
      );
    });

    testWidgets('says which word was tapped', (tester) async {
      final tapped = await pump(tester);

      await tester.tap(find.text('Objetivos'));
      await tester.tap(find.text('Tarefas'));

      expect(tapped, [2, 0]);
    });

    testWidgets('keeps what is trailing at the end of the line', (
      tester,
    ) async {
      await pump(tester, trailing: const Icon(Icons.search));

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        tester.getTopLeft(find.byIcon(Icons.search)).dx,
        greaterThan(tester.getTopRight(find.text('Objetivos')).dx),
      );
    });
  });
}
