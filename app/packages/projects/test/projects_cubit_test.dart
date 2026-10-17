import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:projects/projects.dart';

class _MockRepository extends Mock implements ProjectsRepository {}

void main() {
  late _MockRepository repository;
  final project = Project(
    id: 'p',
    title: 'Site',
    createdAt: DateTime(2026, 6),
    deadline: DateTime(2026, 6, 10),
  );

  setUp(() => repository = _MockRepository());

  blocTest<ProjectsCubit, ProjectsState>(
    'reads the projects',
    setUp: () =>
        when(() => repository.list()).thenAnswer((_) async => [project]),
    build: () => ProjectsCubit(repository: repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      ProjectsState(status: ProjectsStatus.ready, projects: [project]),
    ],
  );

  test(
    'tells the day when a project is removed, since its backlog goes',
    () async {
      var told = 0;
      when(() => repository.delete(any())).thenAnswer((_) async => []);
      final cubit = ProjectsCubit(
        repository: repository,
        onDayChanged: () => told++,
      );

      await cubit.delete('p');
      expect(told, 1);
    },
  );

  test('moves the deadline a day at a time', () async {
    DateTime? sent;
    when(
      () => repository.update(any(), deadline: any(named: 'deadline')),
    ).thenAnswer((invocation) async {
      final deadline =
          invocation.namedArguments[#deadline] as DateTime? Function();
      sent = deadline();
      return [project];
    });
    final cubit = ProjectsCubit(
      repository: repository,
      initial: ProjectsState(
        status: ProjectsStatus.ready,
        projects: [project],
      ),
    );

    await cubit.shiftDeadline('p', 1);
    expect(sent, DateTime(2026, 6, 11));
    await cubit.shiftDeadline('p', -1);
    expect(sent, DateTime(2026, 6, 9));
  });

  blocTest<ProjectsCubit, ProjectsState>(
    'keeps the projects and says why when a write is refused',
    setUp: () => when(
      () => repository.update(any(), done: any(named: 'done')),
    ).thenThrow(const ProjectsFailure('O projeto não respondeu.')),
    build: () => ProjectsCubit(
      repository: repository,
      initial: ProjectsState(
        status: ProjectsStatus.ready,
        projects: [project],
      ),
    ),
    act: (cubit) => cubit.setDone('p', done: true),
    expect: () => [
      ProjectsState(
        status: ProjectsStatus.ready,
        projects: [project],
        failure: const ProjectsFailure('O projeto não respondeu.'),
      ),
    ],
  );
}
