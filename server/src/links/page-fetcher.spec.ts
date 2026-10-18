import { isPublicAddress } from './address';
import { HttpPageFetcher, Unreadable } from './page-fetcher';

/**
 * The guard in front of every page the server reads for someone: it never
 * reaches itself, its network or the cloud's metadata. No spec here leaves
 * the machine; `localhost` resolves without a network.
 */
describe('isPublicAddress', () => {
  it.each([
    '127.0.0.1',
    '10.0.0.5',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.1.10',
    '169.254.169.254',
    '100.64.0.1',
    '0.0.0.0',
    '224.0.0.1',
    '::1',
    '::',
    '[::1]',
    'fe80::1',
    'fd12:3456::1',
    '::ffff:127.0.0.1',
    '::ffff:7f00:1',
    'localhost',
  ])('refuses %s', (address) => {
    expect(isPublicAddress(address)).toBe(false);
  });

  it.each(['8.8.8.8', '172.32.0.1', '142.250.79.14', '2800:3f0:4001::200e'])(
    'lets %s through',
    (address) => {
      expect(isPublicAddress(address)).toBe(true);
    },
  );
});

describe('HttpPageFetcher', () => {
  const fetcher = new HttpPageFetcher();
  const limits = { maxBytes: 1024, truncate: true, accept: '*/*' };

  it.each([
    'http://127.0.0.1:3000/api/users/me',
    'http://169.254.169.254/latest/meta-data/',
    'http://[::1]/',
    'http://localhost:3000/',
    'ftp://example.com/',
  ])('never reads %s', async (url) => {
    await expect(fetcher.fetch(new URL(url), limits)).rejects.toBeInstanceOf(
      Unreadable,
    );
  });
});
