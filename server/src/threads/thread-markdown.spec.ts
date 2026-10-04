import { Message } from './entities/message.entity';
import {
  dayFolder,
  isDayFolder,
  parseThread,
  serializeThread,
  slugify,
  titleFrom,
} from './thread-markdown';

function message(role: Message['role'], text: string, iso: string): Message {
  return {
    id: `${role}-${new Date(iso).getTime()}`,
    role,
    text,
    createdAt: new Date(iso),
  };
}

describe('thread markdown', () => {
  const messages = [
    message('user', 'Buy milk tomorrow', '2026-09-15T19:23:04.123Z'),
    message('agent', 'Noted.', '2026-09-15T19:23:05.456Z'),
  ];

  const front = {
    createdAt: new Date('2026-09-15T19:23:04.123Z'),
    solved: false,
    title: 'Buy milk tomorrow',
  };

  it('round-trips a conversation', () => {
    const parsed = parseThread(serializeThread(front, messages));

    expect(parsed.front).toEqual(front);
    expect(parsed.messages).toEqual(messages);
  });

  it('remembers that a thread was closed', () => {
    const parsed = parseThread(
      serializeThread({ ...front, solved: true }, messages),
    );

    expect(parsed.front.solved).toBe(true);
  });

  it('writes a readable file', () => {
    expect(serializeThread(front, messages)).toBe(
      [
        '---',
        'created: 2026-09-15T19:23:04.123Z',
        'solved: false',
        '---',
        '',
        '# Buy milk tomorrow',
        '',
        '## user @ 2026-09-15T19:23:04.123Z',
        '',
        'Buy milk tomorrow',
        '',
        '## agent @ 2026-09-15T19:23:05.456Z',
        '',
        'Noted.',
        '',
      ].join('\n'),
    );
  });

  it('keeps a markdown heading inside a message body', () => {
    const withHeading = [
      message(
        'agent',
        '## Steps\n\n1. Go to the shop\n2. Buy milk',
        '2026-09-15T19:23:05.456Z',
      ),
    ];

    const parsed = parseThread(
      serializeThread({ ...front, title: 'Buy milk' }, withHeading),
    );

    expect(parsed.messages).toEqual(withHeading);
  });

  it('keeps a rule inside a message body out of the front matter', () => {
    const withRule = [
      message('agent', 'before\n\n---\n\nafter', '2026-09-15T19:23:05.456Z'),
    ];

    const parsed = parseThread(serializeThread(front, withRule));

    expect(parsed.front.title).toBe('Buy milk tomorrow');
    expect(parsed.messages).toEqual(withRule);
  });

  it('parses a file that was hand-written, front matter and all', () => {
    const parsed = parseThread(
      [
        '# Hand written',
        '',
        'a stray note above the first message',
        '',
        '## user @ 2026-09-15T08:00:00.000Z',
        'no blank line after the header',
        '',
        '',
        '## agent @ 2026-09-15T08:00:01.000Z',
        '',
        'trailing blanks   ',
        '',
      ].join('\n'),
    );

    // No front matter at all: an open thread called whatever its heading
    // says, which started when its first message did.
    expect(parsed.front.title).toBe('Hand written');
    expect(parsed.front.solved).toBe(false);
    expect(parsed.front.createdAt).toBeUndefined();
    expect(parsed.messages.map((m) => m.text)).toEqual([
      'no blank line after the header',
      'trailing blanks',
    ]);
  });

  it('returns nothing for an empty file', () => {
    expect(parseThread('')).toEqual({
      front: { createdAt: undefined, solved: false, title: '' },
      messages: [],
    });
  });
});

describe('slugify', () => {
  it('makes a path-safe file name', () => {
    expect(slugify('Buy milk tomorrow!')).toBe('buy-milk-tomorrow');
  });

  it('strips accents', () => {
    expect(slugify('Reunião às três')).toBe('reuniao-as-tres');
  });

  it('caps the length without a trailing hyphen', () => {
    const slug = slugify('a '.repeat(60));
    expect(slug.length).toBeLessThanOrEqual(48);
    expect(slug.endsWith('-')).toBe(false);
  });

  it('falls back when nothing survives', () => {
    expect(slugify('!!!')).toBe('thread');
    expect(slugify('')).toBe('thread');
  });
});

describe('titleFrom', () => {
  it('takes the first line', () => {
    expect(titleFrom('Buy milk\nand eggs')).toBe('Buy milk');
  });

  it('truncates a long line', () => {
    const title = titleFrom('x'.repeat(200));
    expect(title).toHaveLength(62);
    expect(title.endsWith('...')).toBe(true);
  });
});

describe('dayFolder', () => {
  it('formats the local date the way a date is written here', () => {
    expect(dayFolder(new Date(2026, 8, 15, 23, 59))).toBe('15-09-2026');
    expect(dayFolder(new Date(2026, 0, 1, 0, 0))).toBe('01-01-2026');
  });

  it('knows one of its own folders from anything else', () => {
    expect(isDayFolder('15-09-2026')).toBe(true);
    expect(isDayFolder('traces')).toBe(false);
    expect(isDayFolder('2026-09-15')).toBe(false);
  });
});
