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

  testWidgets('answers finish, pause into Pendentes, or Para depois', (
    tester,
  ) async {
    await pump(tester);

    // Text only: none of the three carries an icon.
    expect(find.byType(AppIcon), findsOneWidget);

    for (final (text, decision) in [
      (l10n.guardFinishCurrent, TimingDecision.solveCurrent),
      (l10n.guardToPending, TimingDecision.pauseCurrent),
      (l10n.guardToLater, TimingDecision.laterCurrent),
    ]) {
      await tester.tap(find.text(text));
      verify(() => bloc.add(GuardAnswered(decision))).called(1);
    }
    expect(
      guard.answer(TimingDecision.pauseCurrent)['decision'],
      'pause_current',
    );
    expect(
      guard.answer(TimingDecision.laterCurrent)['decision'],
      'later_current',
    );
  });
}
