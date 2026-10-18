import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { SessionGuard } from '../auth/session.guard';
import { LinkPreviewStore, MemoryLinkPreviewStore } from './link-preview.store';
import { LinksController } from './links.controller';
import { LinksService } from './links.service';
import { Fetched, FetchLimits, PageFetcher, Unreadable } from './page-fetcher';

/**
 * The link previews end to end, with the web replaced by a fake that
 * answers canned pages. Only `Date` is frozen, so a failed page's retry can
 * be reached by moving the clock.
 */
const NOW = new Date('2026-03-10T13:00:00Z');

class StubSessionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      id: 'test-user',
    };
    return true;
  }
}

/** The web, as a map of address to answer. */
class FakeFetcher extends PageFetcher {
  readonly pages = new Map<string, Omit<Fetched, 'url'> & { url?: string }>();
  readonly asked: string[] = [];
  readonly limits: FetchLimits[] = [];

  fetch(url: URL, limits: FetchLimits): Promise<Fetched> {
    this.asked.push(url.href);
    this.limits.push(limits);
    const page = this.pages.get(url.href);
    if (page === undefined) return Promise.reject(new Unreadable('404'));

    return Promise.resolve({ ...page, url: new URL(page.url ?? url.href) });
  }
}

const html = (head: string) => ({
  type: 'text/html',
  body: Buffer.from(`<!doctype html><html><head>${head}</head></html>`),
});

beforeAll(() => {
  jest.useFakeTimers({
    now: NOW,
    doNotFake: [
      'cancelAnimationFrame',
      'cancelIdleCallback',
      'clearImmediate',
      'clearInterval',
      'clearTimeout',
      'hrtime',
      'nextTick',
      'performance',
      'queueMicrotask',
      'requestAnimationFrame',
      'requestIdleCallback',
      'setImmediate',
      'setInterval',
      'setTimeout',
    ],
  });
});

afterAll(() => {
  jest.useRealTimers();
});

afterEach(() => {
  jest.setSystemTime(NOW);
});

describe('LinksController', () => {
  let app: INestApplication<App>;
  let web: FakeFetcher;

  beforeEach(async () => {
    web = new FakeFetcher();
    const moduleRef = await Test.createTestingModule({
      controllers: [LinksController],
      providers: [
        LinksService,
        { provide: LinkPreviewStore, useClass: MemoryLinkPreviewStore },
        { provide: PageFetcher, useValue: web },
      ],
    })
      .overrideGuard(SessionGuard)
      .useClass(StubSessionGuard)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  const preview = (url: string) => http().get('/links/preview').query({ url });

  it("reads a page's title, site and picture once, and keeps them", async () => {
    web.pages.set('https://youtu.be/q8c2Lw3PcrY', {
      ...html(
        '<title>ignored</title>' +
          '<meta property="og:title" content="Paraty em 3 dias &amp; mais">' +
          '<meta property="og:site_name" content="YouTube">' +
          "<meta property='og:image' content='/vi/q8c2/hq.jpg'>",
      ),
      url: 'https://www.youtube.com/watch?v=q8c2Lw3PcrY',
    });

    const first = await preview('https://youtu.be/q8c2Lw3PcrY').expect(200);
    expect(first.body).toEqual({
      url: 'https://youtu.be/q8c2Lw3PcrY',
      title: 'Paraty em 3 dias & mais',
      site: 'YouTube',
      // Resolved against where the redirects ended.
      image: 'https://www.youtube.com/vi/q8c2/hq.jpg',
    });

    const again = await preview('https://youtu.be/q8c2Lw3PcrY').expect(200);
    expect(again.body).toEqual(first.body);
    expect(web.asked).toEqual(['https://youtu.be/q8c2Lw3PcrY']);
    expect(web.limits[0]).toMatchObject({ truncate: true });
  });

  it('falls back to the title tag and the Twitter card', async () => {
    web.pages.set(
      'https://example.com/quartos',
      html(
        '<title>\n  Quartos e tarifas · Pousada\n</title>' +
          '<meta name="twitter:image" content="https://cdn.example.com/b.jpg">',
      ),
    );

    const answer = await preview('https://example.com/quartos').expect(200);
    expect(answer.body).toEqual({
      url: 'https://example.com/quartos',
      title: 'Quartos e tarifas · Pousada',
      site: null,
      image: 'https://cdn.example.com/b.jpg',
    });
  });

  it('answers a link straight to a picture with itself', async () => {
    web.pages.set('https://example.com/a.png', {
      type: 'image/png',
      body: Buffer.from('png'),
    });

    const answer = await preview('https://example.com/a.png').expect(200);
    expect(answer.body).toMatchObject({
      title: null,
      image: 'https://example.com/a.png',
    });
  });

  it('keeps a page that cannot be read, and tries it again a day later', async () => {
    const url = 'https://intranet.empresa.local/reembolso';
    const bare = { url, title: null, site: null, image: null };

    expect((await preview(url).expect(200)).body).toEqual(bare);
    expect((await preview(url).expect(200)).body).toEqual(bare);
    expect(web.asked).toHaveLength(1);

    jest.setSystemTime(new Date(NOW.getTime() + 24 * 60 * 60 * 1000));
    web.pages.set(url, html('<title>Reembolso</title>'));
    expect((await preview(url).expect(200)).body).toEqual({
      ...bare,
      title: 'Reembolso',
    });
    expect(web.asked).toHaveLength(2);
  });

  it('reads one page once for two cards opened together', async () => {
    web.pages.set('https://example.com/', html('<title>Um</title>'));

    await Promise.all([
      preview('https://example.com/').expect(200),
      preview('https://example.com/').expect(200),
    ]);
    expect(web.asked).toEqual(['https://example.com/']);
  });

  it('refuses what is not a web address, in Portuguese', async () => {
    const refused = async (url: string | undefined) =>
      (
        await (
          url === undefined ? http().get('/links/preview') : preview(url)
        ).expect(400)
      ).body as { message: string };

    expect((await refused(undefined)).message).toBe('Faltou o link.');
    expect((await refused('file:///etc/passwd')).message).toBe(
      'Só dá para ler links http ou https.',
    );
    expect((await refused('não é link')).message).toBe(
      'Esse link não parece um endereço da web.',
    );
    expect((await refused('https://a:b@example.com/')).message).toBe(
      'Links com usuário e senha não são lidos.',
    );
    expect(web.asked).toEqual([]);
  });

  it('proxies a picture, cached and sandboxed', async () => {
    web.pages.set('https://cdn.example.com/b.jpg', {
      type: 'image/jpeg',
      body: Buffer.from([0xff, 0xd8, 0xff]),
    });

    const answer = await http()
      .get('/links/image')
      .query({ url: 'https://cdn.example.com/b.jpg' })
      .expect(200);
    expect(answer.headers['content-type']).toBe('image/jpeg');
    expect(answer.headers['cache-control']).toBe('private, max-age=604800');
    expect(answer.headers['content-security-policy']).toContain('sandbox');
    expect(Buffer.from(answer.body as Buffer)).toEqual(
      Buffer.from([0xff, 0xd8, 0xff]),
    );
    expect(web.limits[0]).toMatchObject({ truncate: false });
  });

  it('proxies only pictures a card can draw', async () => {
    web.pages.set('https://example.com/x.svg', {
      type: 'image/svg+xml',
      body: Buffer.from('<svg onload="alert(1)"/>'),
    });
    web.pages.set('https://example.com/', html('<title>Um</title>'));

    for (const url of [
      'https://example.com/x.svg',
      'https://example.com/',
      'https://example.com/missing.jpg',
    ]) {
      await http().get('/links/image').query({ url }).expect(404);
    }
  });
});
