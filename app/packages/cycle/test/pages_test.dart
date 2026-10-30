import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:cycle/cycle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockCycleRepository extends Mock implements CycleRepository {}

void main() {
  /// Thursday 29 October 2026, ten in the morning: the second day of a
  /// period that began on the 28th. The weekend of the 31st is ahead.
  final now = DateTime(2026, 10, 29, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));
  final rhythm = Rhythm(
    cycle: Cycle(lastStart: DateTime(2026, 10, 28)),
    daysOff: [
      DayOff(id: 'finados', day: DateTime(2026, 11, 2), title: 'Finados'),
      DayOff(id: 'w1', day: DateTime(2026, 11, 7), kind: DayKind.work),
      DayOff(id: 'w2', day: DateTime(2026, 11, 8), kind: DayKind.work),
    ],
  );

  late _MockCycleRepository repository;
  late CycleCubit cubit;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(DayKind.off);
  });

  setUp(() {
    repository = _MockCycleRepository();
    cubit = CycleCubit(
      repository: repository,
      initial: CycleState(status: CycleStatus.ready, data: rhythm),
    );
    when(() => repository.periodStarted(any())).thenAnswer((_) async => rhythm);
    when(() => repository.saveCycle(any())).thenAnswer((_) async => rhythm);
    when(
      () => repository.addDay(
        any(),
        kind: any(named: 'kind'),
        title: any(named: 'title'),
      ),
    ).thenAnswer((_) async => rhythm);
    when(() => repository.removeDay(any())).thenAnswer((_) async => rhythm);
  });

  setUpAll(() {
    registerFallbackValue(Cycle(lastStart: DateTime(2026)));
  });

  void testAt(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(now), () => body(tester)),
    );
  }

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view
      ..physicalSize = const Size(600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pump();
  }

  group('CyclePage', () {
    testAt('draws today and says the period began with its button', (
      tester,
    ) async {
      await pump(tester, const CyclePage());

      expect(find.text(l10n.cycleTodayOf(2, 28)), findsOneWidget);
      expect(
        find.text(l10n.cycleNextPredicted(DateTime(2026, 11, 25))),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.cycleStarted));
      await tester.pump();
      verify(() => repository.periodStarted(DateTime(2026, 10, 29))).called(1);
    });

    testAt('a day ahead on the sheet moves the next period there', (
      tester,
    ) async {
      await pump(tester, const CyclePage());
      unawaited(
        showCycleDaySheet(
          tester.element(find.byType(CyclePage)),
          DateTime(2026, 11, 23),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.cycleDayStarted), findsNothing);
      await tester.tap(find.text(l10n.cycleDayWillStart));
      await tester.pumpAndSettle();
      final saved =
          verify(() => repository.saveCycle(captureAny())).captured.single
              as Cycle;
      expect(saved.nextStart, DateTime(2026, 11, 23));
    });

    testAt('a day gone on the sheet is a period that began', (tester) async {
      await pump(tester, const CyclePage());
      unawaited(
        showCycleDaySheet(
          tester.element(find.byType(CyclePage)),
          DateTime(2026, 10, 27),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.cycleDayWillStart), findsNothing);
      await tester.tap(find.text(l10n.cycleDayStarted));
      await tester.pumpAndSettle();
      verify(() => repository.periodStarted(DateTime(2026, 10, 27))).called(1);
    });
  });

  group('DaysOffPage', () {
    testAt('lists the weekends, the dates and the next period in order', (
      tester,
    ) async {
      await pump(tester, const DaysOffPage());

      expect(
        find.text(l10n.cycleDayTitle(DateTime(2026, 11, 2))),
        findsNothing,
      );
      expect(
        find.text(l10n.daysOffEntry(DateTime(2026, 11, 2), 'Finados')),
        findsOneWidget,
      );
      // Four weekends ahead in 30 days, one of them put back to work.
      expect(find.text(l10n.daysOffWork), findsNWidgets(3));
      expect(find.text(l10n.daysOffUndo), findsOneWidget);
    });

    testAt('Trabalhar puts both days of that weekend back to work', (
      tester,
    ) async {
      await pump(tester, const DaysOffPage());
      await tester.tap(find.text(l10n.daysOffWork).first);
      await tester.pump();

      verify(
        () => repository.addDay(DateTime(2026, 10, 31), kind: DayKind.work),
      ).called(1);
      verify(
        () => repository.addDay(DateTime(2026, 11), kind: DayKind.work),
      ).called(1);
    });

    testAt('Desfazer takes the weekend’s two dates away', (tester) async {
      await pump(tester, const DaysOffPage());
      await tester.tap(find.text(l10n.daysOffUndo));
      await tester.pump();

      verify(() => repository.removeDay('w1')).called(1);
      verify(() => repository.removeDay('w2')).called(1);
    });

    testAt('a date off tapped can be taken away', (tester) async {
      await pump(tester, const DaysOffPage());
      await tester.tap(
        find.text(l10n.daysOffEntry(DateTime(2026, 11, 2), 'Finados')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daysOffRemove));
      await tester.pumpAndSettle();

      verify(() => repository.removeDay('finados')).called(1);
    });

    testAt('the + writes a date off down with its name', (tester) async {
      await pump(tester, const DaysOffPage());
      await tester.tap(
        find.descendant(
          of: find.byType(AppAddRow),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Viagem');
      await tester.tap(find.text(l10n.daysOffAddConfirm));
      await tester.pumpAndSettle();

      verify(
        () => repository.addDay(DateTime(2026, 10, 30), title: 'Viagem'),
      ).called(1);
    });
  });
}
