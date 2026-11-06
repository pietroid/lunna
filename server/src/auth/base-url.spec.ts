import { baseUrlOf } from './base-url';

describe('baseUrlOf', () => {
  it('keeps a single origin as it is', () => {
    expect(baseUrlOf(['http://localhost:3000'])).toBe('http://localhost:3000');
  });

  it('answers on each host, falling back to the first', () => {
    expect(
      baseUrlOf([
        'https://lunna.pietroteruya.dev',
        'https://www.lunna.pietroteruya.dev',
      ]),
    ).toEqual({
      allowedHosts: ['lunna.pietroteruya.dev', 'www.lunna.pietroteruya.dev'],
      fallback: 'https://lunna.pietroteruya.dev',
      protocol: 'https',
    });
  });

  it('refuses an empty list', () => {
    expect(() => baseUrlOf([])).toThrow();
  });
});
