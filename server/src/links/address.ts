import { isIP } from 'net';

/**
 * Whether [address] (an IPv4 or IPv6 literal) is somewhere on the public
 * internet. The server reads pages for whoever pastes a link, so it must
 * never be pointed at itself, the Pi's network or the cloud's metadata.
 */
export function isPublicAddress(address: string): boolean {
  const bare = address.replace(/^\[|\]$/g, '').toLowerCase();
  switch (isIP(bare)) {
    case 4:
      return isPublicV4(bare);
    case 6:
      return isPublicV6(bare);
    default:
      return false;
  }
}

function isPublicV4(address: string): boolean {
  const [a, b] = address.split('.').map(Number);
  return !(
    a === 0 || // this network
    a === 10 ||
    a === 127 ||
    (a === 100 && b >= 64 && b <= 127) || // carrier-grade NAT
    (a === 169 && b === 254) || // link-local, the cloud's metadata
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    (a === 192 && b === 0) || // protocol assignments
    (a === 198 && (b === 18 || b === 19)) || // benchmarking
    a >= 224 // multicast and reserved
  );
}

function isPublicV6(address: string): boolean {
  if (address === '::' || address === '::1') return false;

  // An IPv4 address carried in IPv6 is judged as itself.
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(address);
  if (mapped) return isPublicV4(mapped[1]);
  if (address.startsWith('::ffff:')) return false;

  const first = parseInt(address.split(':')[0] || '0', 16);
  return !(
    (first & 0xfe00) === 0xfc00 || // unique local
    (first & 0xffc0) === 0xfe80 || // link-local
    (first & 0xff00) === 0xff00 // multicast
  );
}
