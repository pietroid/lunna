import {
  Controller,
  Get,
  Header,
  Query,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { SessionGuard } from '../auth/session.guard';
import { LinkPreview } from './link.types';
import { LinksService } from './links.service';
import { requireLink } from './request';

/**
 * What the links in the notes say about themselves, for their cards.
 *
 * Behind the session, so the server reads pages only for the people who use
 * it, and is nobody's open proxy.
 */
@Controller('links')
@UseGuards(SessionGuard)
export class LinksController {
  constructor(private readonly links: LinksService) {}

  /** The link's title, site and picture, read once and kept. */
  @Get('preview')
  preview(@Query('url') raw?: string): Promise<LinkPreview> {
    return this.links.preview(requireLink(raw));
  }

  /**
   * A link's picture, from the app's own origin, which is the only way the
   * web build can draw a picture from another site.
   */
  @Get('image')
  @Header('Cache-Control', 'private, max-age=604800')
  @Header('X-Content-Type-Options', 'nosniff')
  @Header('Content-Security-Policy', "default-src 'none'; sandbox")
  async image(@Query('url') raw?: string): Promise<StreamableFile> {
    const image = await this.links.image(requireLink(raw).url);
    return new StreamableFile(image.body, {
      type: image.type,
      length: image.body.length,
    });
  }
}
