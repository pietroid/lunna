import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timeline/timeline.dart';

class _MockTimelineRepository extends Mock implements TimelineRepository {}

/// Ten in the morning, wherever this runs: the page heads days by [clock].
final _now = DateTime(2026, 6, 10, 10);

TimelineEvent _done(String id, DateTime at, {String notes = ''}) =>
    TimelineEvent(
      id: id,
      title: id,
      notes: notes,
      section: TimelineSection.backlog,
      startTime: at,
      endTime: at,
      durationMinutes: 15,
    );

void main() {
  setUpAll(() => registerFallbackValue(_done('fallback', _now)));

  late _MockTimelineRepository repository;

  setUp(() => repository = _MockTimelineRepository());

  final first = [
    _done('a', _now.subtract(const Duration(minutes: 10))),
    _done('b', _now.subtract(const Duration(hours: 1))),
  ];
  final second = [_done('c', _now.subtract(const Duration(days: 1)))];

  group('DoneArchiveCubit', () {
    blocTest<DoneArchiveCubit, DoneArchiveState>(
      'reads the first page, and the next one after its last task',
      setUp: () {
        when(
          () => repository.fetchDone(limit: 2),
        ).thenAnswer((_) async => first);
        when(
          () => repository.fetchDone(after: first.last, limit: 2),
        ).thenAnswer((_) async => second);
      },
      build: () => DoneArchiveCubit(repository: repository, pageSize: 2),
      act: (cubit) async {
        await cubit.load();
        await cubit.more();
        // A short page was the last one: nothing more is asked.
        await cubit.more();
      },
      expect: () => [
        const DoneArchiveState(),
        DoneArchiveState(
          status: DoneArchiveStatus.ready,
          done: first,
          hasMore: true,
        ),
        DoneArchiveState(
          status: DoneArchiveStatus.ready,
          done: first,
          hasMore: true,
          loadingMore: true,
        ),
        DoneArchiveState(
          status: DoneArchiveStatus.ready,
          done: [...first, ...second],
        ),
      ],
      verify: (_) => verify(
        () => repository.fetchDone(after: first.last, limit: 2),
      ).called(1),
    );

    blocTest<DoneArchiveCubit, DoneArchiveState>(
      'looks for the words once typing pauses, and only the last ones',
      setUp: () {
        when(
          () => repository.fetchDone(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => second);
      },
      build: () => DoneArchiveCubit(
        repository: repository,
        debounce: const Duration(milliseconds: 10),
      ),
      act: (cubit) async {
        cubit
          ..search('ped')
          ..search('pedir');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (cubit) {
        verify(
          () => repository.fetchDone(
            query: 'pedir',
            limit: any(named: 'limit'),
          ),
        ).called(1);
        verifyNever(
          () => repository.fetchDone(
            query: 'ped',
            limit: any(named: 'limit'),
          ),
        );
        expect(cubit.state.done, second);
        expect(cubit.state.query, 'pedir');
      },
    );

    blocTest<DoneArchiveCubit, DoneArchiveState>(
      'says so when the first page cannot be read',
      setUp: () {
        when(
          () => repository.fetchDone(limit: any(named: 'limit')),
        ).thenThrow(const TimelineFailure('offline'));
      },
      build: () => DoneArchiveCubit(repository: repository),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        const DoneArchiveState(status: DoneArchiveStatus.failure),
      ],
    );
  });

  group('DoneArchivePage', () {
    Future<List<TimelineEvent>> pump(WidgetTester tester) async {
      final opened = <TimelineEvent>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) =>
                DoneArchiveCubit(repository: repository, pageSize: 10)..load(),
            child: DoneArchivePage(onOpen: (card) async => opened.add(card)),
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('heads the days Hoje and Ontem, and opens a task', (
      tester,
    ) async {
      await withClock(Clock.fixed(_now), () async {
        when(
          () => repository.fetchDone(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [...first, ...second]);

        final opened = await pump(tester);

        expect(find.text('Hoje'), findsOneWidget);
        expect(find.text('Ontem'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('b')).dy,
          lessThan(tester.getTopLeft(find.text('Ontem')).dy),
        );

        await tester.tap(find.text('c'));
        await tester.pump();
        expect(opened.map((it) => it.id), ['c']);
      });
    });

    testWidgets('tells an empty archive from a search with no match', (
      tester,
    ) async {
      when(
        () => repository.fetchDone(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      await pump(tester);
      expect(
        find.textContaining('Nada concluído ainda'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.textContaining('Nenhuma tarefa feita'), findsOneWidget);
    });
  });
}
