import 'package:flutter_test/flutter_test.dart';
import 'package:projects/projects.dart';

void main() {
  group('Project', () {
    test('reads itself off the wire, the deadline as a day here', () {
      final project = Project.fromJson(const {
        'id': 'p',
        'title': 'Site',
        'notes': 'Ideias',
        'deadline': '2026-06-24',
        'createdAt': '2026-06-01T12:00:00.000Z',
        'doneAt': null,
        'tasks': [
          {
            'id': 't',
            'title': 'Textos',
            'minutes': 30,
            'place': 'queue',
            'at': '2026-06-10T13:00:00.000Z',
          },
        ],
      });

      expect(project.deadline, DateTime(2026, 6, 24));
      expect(project.isDone, isFalse);
      expect(project.tasks.single.place, TaskPlace.queue);
      expect(
        project.tasks.single.at,
        DateTime.utc(2026, 6, 10, 13).toLocal(),
      );
    });

    test('fills its bar with time, from written down to the deadline', () {
      final project = Project(
        id: 'p',
        title: 'Site',
        createdAt: DateTime(2026, 6),
        deadline: DateTime(2026, 6, 10),
      );

      expect(project.progressAt(DateTime(2026, 6)), 0);
      expect(project.progressAt(DateTime(2026, 6, 6)), closeTo(0.5, 1e-9));
      expect(project.progressAt(DateTime(2026, 7)), 1);
      expect(project.daysLeftAt(DateTime(2026, 6, 8, 23)), 2);
      expect(project.daysLeftAt(DateTime(2026, 6, 12)), -2);
    });

    test('has no bar and no days left without a deadline', () {
      final project = Project(
        id: 'p',
        title: 'Violão',
        createdAt: DateTime(2026, 6),
      );

      expect(project.progressAt(DateTime(2026, 6, 6)), isNull);
      expect(project.daysLeftAt(DateTime(2026, 6, 6)), isNull);
    });
  });
}
