import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('pt'));
  final guard = StartNowGuard(
    taskId: 'b',
    index: 0,
    currentId: 'a',
    currentTitle: 'Roteiro',
    currentStart: DateTime(2026, 10, 28, 9, 40),
    currentEnd: DateTime(2026, 10, 28, 10, 30),
  );

  late _MockTimelineBloc bloc;

  setUp(() {
    bloc = _MockTimelineBloc();
    when(() => bloc.state).thenReturn(const TimelineState());
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<TimelineBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.current,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GuardSheet(guard: guard, busy: false)),
      ),
    ),
  );

  testWidgets('asks one yes or no: yes pauses into Pendentes, no cancels', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(l10n.guardPauseTitle('Roteiro')), findsOneWidget);
    expect(find.text(l10n.guardPauseBody('Roteiro')), findsOneWidget);
    // The old answers are gone (#89).
    expect(find.byType(AppButton), findsNWidgets(2));

    await tester.tap(find.text(l10n.guardPauseYes));
    verify(
      () => bloc.add(const GuardAnswered(TimingDecision.pauseCurrent)),
    ).called(1);
    await tester.tap(find.text(l10n.guardPauseNo));
    verify(() => bloc.add(const GuardDismissed())).called(1);
    expect(
      guard.answer(TimingDecision.pauseCurrent)['decision'],
      'pause_current',
    );
  });

  testWidgets('over a fixed block, asks to begin after it', (tester) async {
    final block = TimelineEvent(
      id: 'a',
      title: 'Roteiro',
      section: TimelineSection.agora,
      kind: CardKind.event,
      started: true,
      startTime: guard.currentStart,
      endTime: guard.currentEnd,
      durationMinutes: 50,
      workMinutes: 50,
    );
    when(() => bloc.state).thenReturn(TimelineState(cards: [block]));
    await pump(tester);

    expect(find.text(l10n.guardWaitTitle('Roteiro')), findsOneWidget);
    expect(find.text(l10n.guardWaitBody('Roteiro', '10:30')), findsOneWidget);
    await tester.tap(find.text(l10n.guardWaitYes));
    verify(
      () => bloc.add(const GuardAnswered(TimingDecision.pauseCurrent)),
    ).called(1);
  });
}
