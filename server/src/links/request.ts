import { BadRequestException } from '@nestjs/common';

const MAX_LINK = 2048;

/** A link as the notes write it, and the address it is. */
export interface Link {
  link: string;
  url: URL;
}

/**
 * The link a route was asked about, as an address the server may read:
 * http or https, and nothing else. Refuses rather than guesses.
 */
export function requireLink(raw: unknown): Link {
  if (typeof raw !== 'string' || raw.trim() === '') {
    throw new BadRequestException('Faltou o link.');
  }
  if (raw.length > MAX_LINK) {
    throw new BadRequestException('Esse link é longo demais.');
  }

  const link = raw.trim();
  let url: URL;
  try {
    url = new URL(link);
  } catch {
    throw new BadRequestException('Esse link não parece um endereço da web.');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new BadRequestException('Só dá para ler links http ou https.');
  }
  if (url.username !== '' || url.password !== '') {
    throw new BadRequestException('Links com usuário e senha não são lidos.');
  }

  return { link, url };
}
