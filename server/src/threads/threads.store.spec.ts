import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { Message, MessageMetadata } from './entities/message.entity';
import { dayFolder, messageId } from './thread-markdown';
import { ThreadsStore } from './threads.store';

function message(
  role: Message['role'],
  text: string,
  createdAt: Date,
  metadata?: MessageMetadata,
): Message {
  return { id: messageId(role, createdAt), role, text, createdAt, metadata };
}

describe('ThreadsStore', () => {
  let root: string;
  let store: ThreadsStore;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-threads-'));
    process.env.FOCUS_DATA_DIR = root;
    store = new ThreadsStore();
  });

  afterEach(async () => {
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  /** A thread started on [at], with [text] said in it. */
  async function started(
    slug: string,
    at: Date,
    text = 'Buy milk',
  ): Promise<void> {
    await store.create('u1', slug, text, at);
    await store.append('u1', slug, [message('user', text, at)]);
  }

  it('returns null for a thread that does not exist', async () => {
    expect(await store.read('u1', 'nope')).toBeNull();
  });

  it('writes to <user>/<day>/<slug>.md', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    await started('buy-milk', at);

    const file = path.join(root, 'u1', dayFolder(at), 'buy-milk.md');
    await expect(fs.readFile(file, 'utf8')).resolves.toContain('Buy milk');
  });

  it('keeps a whole conversation in the one file it started in', async () => {
    const day1 = new Date(2026, 8, 15, 10, 0);
    const day2 = new Date(2026, 8, 16, 9, 0);

    await started('buy-milk', day1, 'first');
    await store.append('u1', 'buy-milk', [message('user', 'second', day2)]);

    const thread = await store.read('u1', 'buy-milk');
    expect(thread?.messages.map((m) => m.text)).toEqual(['first', 'second']);
    // The folder is the day it started, so a thread is written once and never
    // moves, however long it runs.
    expect(await fs.readdir(path.join(root, 'u1'))).toEqual([dayFolder(day1)]);
    expect(thread?.createdAt).toEqual(day1);
    expect(thread?.updatedAt).toEqual(day2);
  });

  it('appends without dropping what is already there', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    const later = new Date(2026, 8, 15, 10, 1);

    await started('t', at, 'first');
    await store.append('u1', 't', [message('agent', 'second', later)]);

    const thread = await store.read('u1', 't');
    expect(thread?.messages.map((m) => m.text)).toEqual(['first', 'second']);
  });

  it('will not append to a thread that was never started', async () => {
    await store.append('u1', 'ghost', [
      message('user', 'hello', new Date(2026, 8, 15, 10, 0)),
    ]);

    expect(await store.read('u1', 'ghost')).toBeNull();
  });

  it('lists every thread across every day, newest day first', async () => {
    await started('older', new Date(2026, 8, 14, 10, 0));
    await started('newer', new Date(2026, 8, 16, 10, 0));

    expect(await store.listSlugs('u1')).toEqual(['newer', 'older']);
    expect((await store.readAll('u1')).map((t) => t.slug).sort()).toEqual([
      'newer',
      'older',
    ]);
  });

  it('keeps one user out of another user thread', async () => {
    await started('private', new Date(2026, 8, 15, 10, 0), 'secret');

    expect(await store.read('u2', 'private')).toBeNull();
    expect(await store.listSlugs('u2')).toEqual([]);
  });

  it('refuses a slug that walks out of the data directory', async () => {
    const escaped = await store.read('u1', '../../etc');
    expect(escaped).toBeNull();
    await expect(fs.readdir(root)).resolves.toEqual([]);
  });

  it('remembers that a thread was solved, and its new name', async () => {
    await started('done', new Date(2026, 8, 15, 10, 0), 'ship it');

    expect(await store.read('u1', 'done')).toMatchObject({
      solved: false,
      title: 'ship it',
    });

    await store.updateState('u1', 'done', { solved: true, title: 'Shipped' });

    expect(await store.read('u1', 'done')).toMatchObject({
      solved: true,
      title: 'Shipped',
    });
  });

  it('keeps the messages when only the state changes', async () => {
    await started('done', new Date(2026, 8, 15, 10, 0), 'ship it');
    await store.updateState('u1', 'done', { solved: true });

    expect((await store.read('u1', 'done'))?.messages).toHaveLength(1);
  });

  it('knows a name is taken', async () => {
    await started('buy-milk', new Date(2026, 8, 15, 10, 0));

    expect(await store.exists('u1', 'buy-milk')).toBe(true);
    expect(await store.exists('u1', 'buy-bread')).toBe(false);
  });

  it('removes a thread and the traces that explain it', async () => {
    await started('gone', new Date(2026, 8, 15, 10, 0));
    await store.saveTrace('u1', 'gone', 't_1', { events: [] });

    await store.remove('u1', 'gone');

    expect(await store.read('u1', 'gone')).toBeNull();
    expect(await store.readTrace('u1', 'gone', 't_1')).toBeNull();
  });

  it('keeps traces out of the day folders', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    await started('traced', at);
    await store.saveTrace('u1', 'traced', 't_1', { events: ['one'] });

    // A day folder stays readable as the list of conversations that started
    // that day, and nothing else.
    expect(await fs.readdir(path.join(root, 'u1', dayFolder(at)))).toEqual([
      'traced.md',
    ]);
    expect(await store.readTrace('u1', 'traced', 't_1')).toEqual({
      events: ['one'],
    });
  });

  it("keeps a message's trace id across a round trip to disk", async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    await store.create('u1', 'traced', 'Traced', at);
    await store.append('u1', 'traced', [
      message('agent', '', at, {
        contentType: 'a2ui',
        a2ui: { component: 'Text', text: 'Noted.' },
        traceId: 't_abc',
        model: 'stub',
        parseStrategy: 'direct',
      }),
    ]);

    const thread = await store.read('u1', 'traced');
    expect(thread?.messages[0].metadata).toMatchObject({
      traceId: 't_abc',
      model: 'stub',
      parseStrategy: 'direct',
    });
  });

  it('says nothing about when a thread happens', async () => {
    await started('idea', new Date(2026, 8, 14, 10, 0), 'some day');

    // The whole point of the layout: a thread is a conversation, and an hour
    // for it is the calendar's business.
    expect(await store.read('u1', 'idea')).not.toHaveProperty('timing');
  });
});
