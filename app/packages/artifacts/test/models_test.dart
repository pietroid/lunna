import 'package:artifacts/artifacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArtifactsData', () {
    final answer = {
      'artifacts': [
        {
          'id': 'a',
          'title': 'Mapa astral · Camila',
          'notes': 'Nasceu às 14h',
          'typeId': 'mapa',
          'minutes': 180,
          'doneMinutes': 45,
          'value': 350,
          'blockMinutes': 60,
          'deadline': '2026-10-23',
          'createdAt': '2026-10-01T12:00:00.000Z',
          'doneAt': null,
          'tasks': [
            {
              'id': 't',
              'title': 'Cálculo',
              'minutes': 45,
              'place': 'done',
              'doneAt': '2026-10-20T13:00:00.000Z',
            },
          ],
        },
        {
          'id': 'b',
          'title': 'Curso',
          'notes': '',
          'typeId': null,
          'minutes': 600,
          'doneMinutes': 0,
          'value': null,
          'blockMinutes': null,
          'deadline': null,
          'createdAt': '2026-09-01T12:00:00.000Z',
          'doneAt': '2026-10-14T18:00:00.000Z',
          'tasks': <Object>[],
        },
      ],
      'catalog': [
        {
          'id': 'atend',
          'name': 'Atendimentos',
          'types': [
            {
              'id': 'mapa',
              'name': 'Mapa astral',
              'minutes': 180,
              'price': 350,
              'blockMinutes': 60,
            },
          ],
        },
      ],
      'goals': [
        {
          'id': 'g',
          'kind': 'count',
          'typeId': 'mapa',
          'target': 3,
          'period': 'week',
          'start': '2026-10-19',
          'end': '2026-10-26',
          'done': 1,
          'queued': 1,
        },
      ],
      'schedule': {
        'needMinutes': 135,
        'freeMinutes': 1560,
        'until': '2026-10-31',
      },
      'topTypes': ['mapa', 'gone'],
    };

    test('reads the answer, finding each kind and shelf in the catalogue', () {
      final data = ArtifactsData.fromJson(answer);
      final mapa = data.catalog.single.types.single;

      expect(data.queue.map((a) => a.id), ['a']);
      expect(data.done.map((a) => a.id), ['b']);
      final a = data.queue.single;
      expect(a.type, mapa);
      expect(a.category?.name, 'Atendimentos');
      expect(
        [a.minutes, a.doneMinutes, a.value, a.blockMinutes],
        [
          180,
          45,
          350,
          60,
        ],
      );
      expect(a.deadline, DateTime(2026, 10, 23));
      expect([a.steps, a.stepsDone], [1, 1]);
      expect(data.done.single.type, isNull);

      final goal = data.goals.single;
      expect(goal.kind, GoalKind.count);
      expect(goal.type, mapa);
      expect(goal.start, DateTime(2026, 10, 19));
      expect(goal.isActiveAt(DateTime(2026, 10, 21)), isTrue);
      expect(goal.isActiveAt(DateTime(2026, 10, 18)), isFalse);

      expect(data.schedule.until, DateTime(2026, 10, 31));
      // A kind no longer in the catalogue is left out.
      expect(data.topTypes, [mapa]);
    });

    test('fills a bar with time, from written down to the deadline', () {
      final artifact = Artifact(
        id: 'p',
        title: 'Site',
        minutes: 60,
        createdAt: DateTime(2026, 6),
        deadline: DateTime(2026, 6, 10),
      );

      expect(artifact.progressAt(DateTime(2026, 6)), 0);
      expect(artifact.progressAt(DateTime(2026, 6, 6)), closeTo(0.5, 1e-9));
      expect(artifact.progressAt(DateTime(2026, 7)), 1);
      expect(artifact.daysLeftAt(DateTime(2026, 6, 8, 23)), 2);
      expect(artifact.daysLeftAt(DateTime(2026, 6, 12)), -2);
    });
  });

  group('Shelf', () {
    const mapa = CatalogType(id: 'mapa', name: 'Mapa astral', minutes: 60);
    const shelf = CatalogCategory(id: 'atend', name: 'A', types: [mapa]);
    final ofMapa = Artifact(
      id: 'a',
      title: 'Mapa',
      minutes: 60,
      createdAt: DateTime(2026),
      type: mapa,
      category: shelf,
    );
    final loose = Artifact(
      id: 'b',
      title: 'Avulsa',
      minutes: 60,
      createdAt: DateTime(2026),
    );

    test('keeps everything, a shelf, or a kind', () {
      expect(const Shelf().keeps(loose), isTrue);
      expect(const Shelf(category: 'atend').keeps(ofMapa), isTrue);
      expect(const Shelf(category: 'atend').keeps(loose), isFalse);
      expect(const Shelf(type: 'mapa').keeps(ofMapa), isTrue);
      expect(const Shelf(type: 'other').keeps(ofMapa), isFalse);
    });
  });
}
