import { Injectable } from '@nestjs/common';
import { lookup, LookupAddress } from 'dns';
import * as http from 'http';
import * as https from 'https';
import { isIP, LookupFunction } from 'net';
import { Readable } from 'stream';
import * as zlib from 'zlib';
import { isPublicAddress } from './address';

/** What a link answered: where it ended up, what it is, and its bytes. */
export interface Fetched {
  /** The address after the redirects, which relative links resolve against. */
  url: URL;
  /** The media type, lower case, without its parameters. */
  type: string;
  /** The `charset` the server named, if any. */
  charset?: string;
  body: Buffer;
}

export interface FetchLimits {
  /** How many bytes to read at most. */
  maxBytes: number;
  /** Whether a longer body is cut at [maxBytes] (a page's head is enough),
   * rather than refused (a picture cut short is no picture). */
  truncate: boolean;
  /** What to ask for. */
  accept: string;
}

/** A link that could not be read, for any reason. */
export class Unreadable extends Error {}

/** Reads what a link points at. */
export abstract class PageFetcher {
  abstract fetch(url: URL, limits: FetchLimits): Promise<Fetched>;
}

const TIMEOUT_MS = 5000;
const MAX_REDIRECTS = 4;
const USER_AGENT =
  'Mozilla/5.0 (compatible; LunnaBot/1.0; +https://lunna.pietroteruya.dev)';

/**
 * Resolves a host, and refuses it when any address it has is not public.
 * It is the socket's own lookup, so the address checked is the address
 * connected to, and a host cannot answer one address to a check and
 * another to the connection.
 */
const publicLookup: LookupFunction = (hostname, options, callback) => {
  lookup(hostname, { ...options, all: true }, (error, addresses) => {
    if (error) return callback(error, '', 0);

    const list: LookupAddress[] = addresses;
    if (list.length === 0 || !list.every((a) => isPublicAddress(a.address))) {
      return callback(new Unreadable(`${hostname} is not public`), '', 0);
    }
    if (options.all) {
      callback(null, list);
    } else {
      callback(null, list[0].address, list[0].family);
    }
  });
};

/** The pages, over HTTP, never to an address that is not public. */
@Injectable()
export class HttpPageFetcher extends PageFetcher {
  async fetch(url: URL, limits: FetchLimits): Promise<Fetched> {
    let at = url;
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      const answer = await this._get(at, limits);
      if ('fetched' in answer) return answer.fetched;

      at = new URL(answer.location, at);
    }
    throw new Unreadable('too many redirects');
  }

  private _get(
    url: URL,
    limits: FetchLimits,
  ): Promise<{ location: string } | { fetched: Fetched }> {
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      return Promise.reject(new Unreadable(`${url.protocol} is not http`));
    }
    // An address written out is never looked up, so it is checked here.
    const host = url.hostname.replace(/^\[|\]$/g, '');
    if (isIP(host) !== 0 && !isPublicAddress(host)) {
      return Promise.reject(new Unreadable(`${host} is not public`));
    }

    const client = url.protocol === 'https:' ? https : http;
    return new Promise((resolve, reject) => {
      const request = client.get(
        url,
        {
          lookup: publicLookup,
          timeout: TIMEOUT_MS,
          headers: {
            'user-agent': USER_AGENT,
            accept: limits.accept,
            'accept-language': 'pt-BR,pt;q=0.9,en;q=0.5',
            'accept-encoding': 'gzip, deflate, br',
          },
        },
        (response) => {
          const status = response.statusCode ?? 0;
          const location = response.headers.location;
          if (status >= 300 && status < 400 && location) {
            response.resume();
            return resolve({ location });
          }
          if (status < 200 || status >= 300) {
            response.resume();
            return reject(new Unreadable(`answered ${status}`));
          }

          const [type, ...params] = (response.headers['content-type'] ?? '')
            .toLowerCase()
            .split(';')
            .map((part) => part.trim());
          const charset = params
            .find((param) => param.startsWith('charset='))
            ?.slice('charset='.length)
            .replace(/"/g, '');

          read(decoded(response), limits).then(
            (body) => resolve({ fetched: { url, type, charset, body } }),
            reject,
          );
        },
      );
      request.on('timeout', () => request.destroy(new Unreadable('timed out')));
      request.on('error', (error) =>
        reject(
          error instanceof Unreadable ? error : new Unreadable(error.message),
        ),
      );
    });
  }
}

/** The body as it was meant, whatever it was compressed with. */
function decoded(response: http.IncomingMessage): Readable {
  switch (response.headers['content-encoding']) {
    case 'gzip':
      return response.pipe(zlib.createGunzip());
    case 'deflate':
      return response.pipe(zlib.createInflate());
    case 'br':
      return response.pipe(zlib.createBrotliDecompress());
    default:
      return response;
  }
}

/** Reads [stream] up to the limit, cutting or refusing past it. */
function read(stream: Readable, limits: FetchLimits): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    stream.on('data', (chunk: Buffer) => {
      chunks.push(chunk);
      size += chunk.length;
      if (size <= limits.maxBytes) return;

      stream.destroy();
      if (limits.truncate) {
        resolve(Buffer.concat(chunks).subarray(0, limits.maxBytes));
      } else {
        reject(new Unreadable('too large'));
      }
    });
    stream.on('end', () => resolve(Buffer.concat(chunks)));
    stream.on('error', (error) => reject(new Unreadable(error.message)));
  });
}
