import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:auth/auth.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/home/view/greeting.dart';
import 'package:lunna/landing/landing.dart';

/// Nobody signed in, and nobody signs in.
class _SignedOut extends AuthRepository {
  const _SignedOut();

  @override
  Stream<AppUser?> get user => const Stream.empty();

  @override
  AppUser? get currentUser => null;

  @override
  Future<String?> token() async => null;

  @override
  Future<AppUser?> restore() async => null;

  @override
  Future<void> signInWithGoogle() => Completer<void>().future;

  @override
  Future<void> signOut() async {}
}

void main() {
  /// Half past midnight: the demo is to be shown at ten all the same.
  final night = DateTime(2026, 10, 22, 0, 31);
  final l10n = lookupAppLocalizations(const Locale('pt'));

  void testAt(
    String description,
    Size size,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await withClock(DemoClock.around(Clock.fixed(night)), () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.current,
            locale: const Locale('pt', 'BR'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AuthScreen(
                authRepository: _SignedOut(),
                child: LandingPage(),
              ),
            ),
          ),
        );
        await body(tester);
        // Leave the page, so the clock lets go of the pin.
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  /// Long enough for the scripted answer and the sheet to come in.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder inBar(String text) => find.descendant(
    of: find.byType(AppBottomBar),
    matching: find.text(text),
  );

  group('LandingPage, wide', () {
    const wide = Size(1440, 900);

    testAt('opens the phone on the agent answering the first ask', wide, (
      tester,
    ) async {
      await settle(tester);

      expect(find.text(l10n.landingHeadline), findsOneWidget);
      expect(find.byType(AgentSheet), findsOneWidget);
      expect(find.text(l10n.demoReplyStudy), findsOneWidget);
      expect(find.byType(PlanCard), findsOneWidget);
    });

    testAt('shows the demo at ten in the morning, whatever the hour', wide, (
      tester,
    ) async {
      await settle(tester);
      await tester.tap(find.text(l10n.landingChapterTimeTitle).first);
      await settle(tester);

      final ten = DateTime(2026, 10, 22, DemoClock.hour);
      expect(find.text(greeting(l10n, ten, null)), findsOneWidget);
      expect(clock.now(), ten);
    });

    testAt('choosing Entregas shows Entregas in the phone', wide, (
      tester,
    ) async {
      await settle(tester);
      await tester.tap(find.text(l10n.landingChapterDeliveriesTitle).first);
      await settle(tester);

      expect(find.byType(AgentSheet), findsNothing);
      expect(find.byType(ArtifactsPage), findsOneWidget);
      expect(find.text(l10n.demoDeliveryRenata), findsOneWidget);
      expect(find.text(l10n.landingChapterDeliveriesText), findsOneWidget);
    });

    testAt('a tab tapped in the phone moves the chapter', wide, (
      tester,
    ) async {
      await settle(tester);
      await tester.tap(find.text(l10n.landingChapterDeliveriesTitle).first);
      await settle(tester);
      // Entregas has the agent's bar too.
      final dock = tester.state(find.byType(AskDock));
      // Measured from the phone's bottom bar: the landing moves the phone
      // itself between chapters.
      Rect place() => tester
          .getRect(find.byType(AskBar))
          .shift(-tester.getTopLeft(find.byType(AppBottomBar)));
      final before = place();

      await tester.tap(inBar(l10n.shellTimelineTab));
      await settle(tester);

      // The same dock, where it was: changing tabs moves nothing.
      expect(tester.state(find.byType(AskDock)), same(dock));
      expect(place(), rectMoreOrLessEquals(before));
      expect(find.text(l10n.landingChapterTimeText), findsOneWidget);
      expect(find.text(l10n.landingChapterDeliveriesText), findsNothing);
    });

    testAt('an ask pill asks the phone', wide, (tester) async {
      await settle(tester);
      await tester.tap(find.text(l10n.demoAskDelivery));
      await settle(tester);

      expect(find.text(l10n.demoReplyDelivery), findsOneWidget);
    });
  });

  group('LandingPage, narrow', () {
    const narrow = Size(390, 844);

    testAt('draws the pieces instead of a phone', narrow, (tester) async {
      await settle(tester);

      expect(find.byType(DemoApp), findsNothing);
      expect(find.byType(PlanCard), findsOneWidget);
      expect(find.byType(GoalCard), findsOneWidget);
      expect(find.byType(ArtifactRow), findsNWidgets(2));
    });

    testAt('Aplicar on the plan only marks it applied', narrow, (
      tester,
    ) async {
      await settle(tester);
      final apply = find.text(l10n.agentApply);
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pump();

      expect(find.text(l10n.agentApplied), findsOneWidget);
    });
  });
}
