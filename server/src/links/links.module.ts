import { Module } from '@nestjs/common';
import { LinkPreviewStore } from './link-preview.store';
import { LinksController } from './links.controller';
import { LinksService } from './links.service';
import { HttpPageFetcher, PageFetcher } from './page-fetcher';
import { PgLinkPreviewStore } from './pg-link-preview.store';

/** The previews of the links people write in their notes. */
@Module({
  controllers: [LinksController],
  providers: [
    LinksService,
    { provide: LinkPreviewStore, useClass: PgLinkPreviewStore },
    { provide: PageFetcher, useClass: HttpPageFetcher },
  ],
})
export class LinksModule {}
