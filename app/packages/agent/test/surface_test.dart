import 'package:agent/agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentReply.fromJson with ui', () {
    test('reads the surface in order, binding each block to its data', () {
      final reply = AgentReply.fromJson(const {
        'reply': 'Sua tarde tem duas janelas.',
        'steps': ['Olhei hoje'],
        'ui': [
          {
            'version': 'v0.9',
            'createSurface': {'surfaceId': 'turn-1', 'catalogId': 'x'},
          },
          {
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'turn-1',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['b1', 'b2', 'b3', 'b4', 'b5'],
                },
                {'id': 'b1', 'component': 'Caption', 'text': 'Oi.'},
                {
                  'id': 'b2',
                  'component': 'DayPeek',
                  'day': {'path': '/b2'},
                  'items': {'path': '/b2items'},
                },
                {
                  'id': 'b3',
                  'component': 'Choices',
                  'options': {'path': '/b3'},
                },
                {
                  'id': 'b4',
                  'component': 'ProjectPeek',
                  'project': {'path': '/b4'},
                },
                {'id': 'b5', 'component': 'Carousel'},
              ],
            },
          },
          {
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'turn-1',
              'path': '/',
              'value': {
                'b2': {
                  'day': '2026-10-16',
                  'from': '2026-10-16T16:00:00.000Z',
                  'to': '2026-10-16T21:00:00.000Z',
                },
                'b2items': [
                  {
                    'kind': 'fixed',
                    'title': 'Reunião',
                    'start': '2026-10-16T17:00:00.000Z',
                    'end': '2026-10-16T18:00:00.000Z',
                  },
                  {
                    'kind': 'free',
                    'title': '',
                    'start': '2026-10-16T18:05:00.000Z',
                    'end': '2026-10-16T21:00:00.000Z',
                  },
                ],
                'b3': [
                  {
                    'label': 'Ler às 15:30',
                    'plan': {'id': 'p1', 'changes': <Object>[]},
                  },
                  {'label': 'Só amanhã', 'say': 'Deixa para amanhã'},
                ],
                'b4': {
                  'id': 'x1',
                  'title': 'Tese',
                  'createdAt': '2026-09-01T12:00:00.000Z',
                  'deadline': '2026-11-30',
                  'done': 1,
                  'total': 4,
                  'next': [
                    {'id': 't1', 'title': 'Capítulo 2', 'minutes': 90},
                  ],
                },
              },
            },
          },
        ],
      });

      expect(reply.blocks.map((it) => it.runtimeType), [
        CaptionBlock,
        DayBlock,
        ChoicesBlock,
        ProjectBlock,
      ]);
      final day = reply.blocks[1] as DayBlock;
      expect(day.items.map((it) => it.kind), [PeekKind.fixed, PeekKind.free]);
      expect(day.free, 175);
      expect(reply.options.map((it) => it.say), [null, 'Deixa para amanhã']);
      expect(reply.plans.map((it) => it.id), ['p1']);
      final project = (reply.blocks[3] as ProjectBlock).project;
      expect(project.deadline, DateTime(2026, 11, 30));
      expect(project.next.single.at, isNull);
      expect(reply.steps, ['Olhei hoje']);
    });
  });
}
