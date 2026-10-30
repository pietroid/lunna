import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/menu/menu.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

void main() {
  /// Thursday 29 October 2026, ten in the morning.
  final now = DateTime(2026, 10, 29, 10);
  final l10n = lookupAppLocalizations(const Locale('pt'));
  late _MockTimelineBloc timeline;

  setUp(() => timeline = _MockTimelineBloc());

  Future<void> pump(WidgetTester tester, List<DayMark> marks) async {
    when(() => timeline.state).thenReturn(TimelineState(marks: marks));
    await tester.pumpWidget(
      BlocProvider<TimelineBloc>.value(
        value: timeline,
        child: MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MenuPage()),
        ),
      ),
    );
  }

  testWidgets('Ritmo names today’s phase on Ciclo', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, [
        DayMark(
          day: DateTime(2026, 10, 29),
          kind: DayKind.light,
          cycleDay: 2,
          cycleLength: 28,
          phase: CyclePhase.menstrual,
        ),
      ]);

      expect(find.text(l10n.menuRestSection), findsOneWidget);
      expect(
        find.text(l10n.menuCycleToday(2, l10n.cyclePhaseMenstrual)),
        findsOneWidget,
      );
      expect(find.text(l10n.menuDaysOff), findsOneWidget);
    });
  });

  testWidgets('without a cycle, Ciclo says what it is for', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, const []);

      expect(find.text(l10n.menuCycleHint), findsOneWidget);
    });
  });
}
