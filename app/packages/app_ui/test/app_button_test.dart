import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Color?> labelColor(WidgetTester tester, AppButton button) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(body: Center(child: button)),
      ),
    );
    return tester.widget<Text>(find.text('Terminei')).style?.color;
  }

  testWidgets('labels the accent in onAccent: white on red, black on lime', (
    tester,
  ) async {
    final color = await labelColor(
      tester,
      AppButton(text: 'Terminei', onPressed: () {}),
    );

    expect(color, AppColors.onAccent);
    expect(
      color,
      AppBrand.isLunna ? const Color(0xFFFFFFFF) : isNot(AppColors.ink),
    );
  });

  testWidgets('labels any other fill black or white by its luminance', (
    tester,
  ) async {
    expect(
      await labelColor(
        tester,
        AppButton(
          text: 'Terminei',
          color: const Color(0xFF101010),
          onPressed: () {},
        ),
      ),
      const Color(0xFFFFFFFF),
    );
    expect(
      await labelColor(
        tester,
        AppButton(
          text: 'Terminei',
          color: const Color(0xFFF4F4F4),
          onPressed: () {},
        ),
      ),
      const Color(0xFF000000),
    );
  });

  testWidgets('cuts a label too long for its button rather than overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: AppButton.icon(
                text: 'Terminei de verdade agora',
                icon: const Icon(Icons.check),
                expand: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
