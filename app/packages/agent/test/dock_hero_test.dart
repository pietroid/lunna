import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  /// A page with a dock of its own at the foot, as every page has.
  Widget page(Key key, AppIconData icon) => Scaffold(
    body: const SizedBox.expand(),
    floatingActionButton: DockHero(
      fabIcon: icon,
      child: SizedBox(key: key, width: 358, height: AskBar.height),
    ),
    floatingActionButtonLocation: AskDock.location,
    floatingActionButtonAnimator: AskDock.animator,
  );

  Future<NavigatorState> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.current,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page(const Key('from'), AppIcons.plus),
      ),
    );
    return navigator.currentState!;
  }

  Finder fabWith(AppIconData icon) => find.byWidgetPredicate(
    (widget) => widget is AppFab && widget.iconData == icon,
  );

  testWidgets('a push holds the dock still, drawn with the arriving +', (
    tester,
  ) async {
    final navigator = await pump(tester);
    final before = tester.getRect(find.byKey(const Key('from')));

    final pushed = navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => page(const Key('to'), AppIcons.microphone),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Mid-flight: a picture of the bar beside the arriving page's
    // microphone, where the dock was, and nothing in it takes a tap.
    final shuttle = fabWith(AppIcons.microphone);
    expect(shuttle, findsOneWidget);
    expect(
      tester.getRect(
        find.ancestor(of: shuttle, matching: find.byType(Row)).first,
      ),
      rectMoreOrLessEquals(before),
    );
    final guard = tester.widget<IgnorePointer>(
      find.ancestor(of: shuttle, matching: find.byType(IgnorePointer)).first,
    );
    expect(guard.ignoring, isTrue);

    await tester.pumpAndSettle();
    expect(fabWith(AppIcons.microphone), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('to'))),
      rectMoreOrLessEquals(before),
    );

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Back: the page underneath is the one arriving, and its + is drawn.
    expect(fabWith(AppIcons.plus), findsOneWidget);
    await tester.pumpAndSettle();
    await pushed;
    expect(
      tester.getRect(find.byKey(const Key('from'))),
      rectMoreOrLessEquals(before),
    );
  });
}
