import {
  Body,
  Controller,
  Get,
  Post,
  Param,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { FastifyRequest, FastifyReply } from 'fastify';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser, Public } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ConsumerContentService } from './consumer-content.service';
import { PaginationDto } from './dto/pagination.dto';
import { CategoriesQueryDto } from './dto/categories-query.dto';
import { ReportDurationDto } from './dto/report-duration.dto';
import { requestOrigin } from './media-proxy';

@ApiTags('Consumer Content')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('content')
export class ConsumerContentController {
  constructor(private readonly service: ConsumerContentService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current child content context' })
  getMe(@CurrentUser() user: JwtPayload) {
    return this.service.getMe(user.userId);
  }

  @Get('videos')
  @ApiOperation({ summary: 'List videos (age + plan filtered)' })
  getVideos(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getVideos(
      user.userId,
      requestOrigin(req),
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('audiobooks')
  @ApiOperation({ summary: 'List audiobooks (age + plan filtered)' })
  getAudiobooks(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getAudiobooks(
      user.userId,
      requestOrigin(req),
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('books')
  @ApiOperation({ summary: 'List books (age + plan filtered)' })
  getBooks(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getBooks(
      user.userId,
      requestOrigin(req),
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('categories')
  @ApiOperation({ summary: 'List content categories' })
  getCategories(@Query() query: CategoriesQueryDto) {
    return this.service.getCategories(query.kind);
  }

  @Post('videos/:id/view')
  @ApiOperation({ summary: 'Record a video view' })
  recordVideoView(@Param('id') id: string) {
    return this.service.recordVideoView(id);
  }

  @Post('videos/:id/duration')
  @ApiOperation({ summary: 'Report real video duration (sets only if unknown)' })
  reportVideoDuration(
    @Param('id') id: string,
    @Body() dto: ReportDurationDto,
  ) {
    return this.service.reportVideoDuration(id, dto.durationSec);
  }

  @Post('audiobooks/:id/duration')
  @ApiOperation({ summary: 'Report real audiobook duration (if unknown)' })
  reportAudiobookDuration(
    @Param('id') id: string,
    @Body() dto: ReportDurationDto,
  ) {
    return this.service.reportAudiobookDuration(id, dto.durationSec);
  }

  // @Public content media proxy (audio/thumb/cover/video/pdf) — auth
  // header'siz ishlaydi. Range qo'llab-quvvatlaydi (audio/video seek va
  // M4A moov uchun shart, aks holda telefon player 0:00 da qotadi).
  // storageKey uuid = capability (taxmin qilib bo'lmaydi).
  @Get('media/:segment/:file')
  @Public()
  @ApiOperation({ summary: 'Stream content media (Range-aware proxy)' })
  async streamMedia(
    @Param('segment') segment: string,
    @Param('file') file: string,
    @Req() req: FastifyRequest,
    @Res() reply: FastifyReply,
  ) {
    const range = req.headers.range;
    const obj = await this.service.getMediaStream(segment, file, range);
    reply.header('Accept-Ranges', 'bytes');
    reply.header('Cache-Control', 'public, max-age=86400');
    // Content-Type'ni fayl kengaytmasidan ANIQLAYMIZ — admin audio'ni MIME'siz
    // yuklagani uchun MinIO'da ko'pincha octet-stream/bo'sh saqlanadi va telefon
    // player (just_audio/ExoPlayer/AVPlayer) octet-stream'da 0:00 da qotardi.
    reply.type(this.contentTypeFor(file, obj.contentType));
    if (obj.contentRange) {
      reply.code(206);
      reply.header('Content-Range', obj.contentRange);
    }
    if (obj.contentLength != null) {
      reply.header('Content-Length', String(obj.contentLength));
    }
    return reply.send(obj.stream);
  }

  // Fayl kengaytmasidan to'g'ri MIME — saqlangan tur ishonchli (octet-stream
  // emas) bo'lsa o'shani, aks holda kengaytmadan aniqlaymiz.
  private static readonly MIME: Record<string, string> = {
    m4a: 'audio/mp4',
    aac: 'audio/mp4',
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    ogg: 'audio/ogg',
    opus: 'audio/ogg',
    webm: 'audio/webm',
    mp4: 'video/mp4',
    m4v: 'video/mp4',
    mov: 'video/quicktime',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    gif: 'image/gif',
    pdf: 'application/pdf',
  };

  private contentTypeFor(file: string, stored?: string): string {
    if (stored && stored !== 'application/octet-stream') return stored;
    const ext = file.split('.').pop()?.toLowerCase() ?? '';
    return (
      ConsumerContentController.MIME[ext] ??
      stored ??
      'application/octet-stream'
    );
  }

  // @Public YouTube embed sahifa — bola webview SHU sahifani yuklaydi.
  // Sahifa backend domenida xizmat qilingani uchun iframe'ning referer'i
  // haqiqiy (admin paneldagidek) -> YouTube embed ishlaydi (xato 153 yo'q).
  @Get('yt/:id')
  @Public()
  @ApiOperation({ summary: 'YouTube embed page (real referrer)' })
  youtubeEmbed(@Param('id') id: string, @Res() reply: FastifyReply) {
    if (!/^[\w-]{11}$/.test(id)) {
      reply.code(400).send('Invalid video id');
      return;
    }
    // `origin` — YouTube embed player ruxsatli embedder'ni shu orqali tekshiradi;
    // bo'lmasa Android WebView'da "Xato 153" beradi. Sahifa xizmat qilingan
    // haqiqiy host'ni olamiz. `youtube-nocookie` domeni embed-cheklovlarga
    // bardoshliroq. `enablejsapi=1` ham embed-player'ni to'g'ri sozlaydi.
    const reqHeaders = reply.request.headers;
    const host =
      (reqHeaders['x-forwarded-host'] as string | undefined) ??
      reqHeaders.host ??
      'farzandimedu.uz';
    const origin = `https://${host}`;
    const src =
      `https://www.youtube-nocookie.com/embed/${id}` +
      `?playsinline=1&rel=0&modestbranding=1&enablejsapi=1` +
      `&origin=${encodeURIComponent(origin)}`;
    const html =
      '<!DOCTYPE html><html><head>' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,' +
      'maximum-scale=1,user-scalable=no">' +
      '<style>html,body{margin:0;background:#000;height:100%;overflow:hidden}' +
      'iframe{position:fixed;top:0;left:0;width:100%;height:100%;border:0}' +
      '</style></head><body>' +
      `<iframe src="${src}" ` +
      'allow="autoplay;encrypted-media;picture-in-picture" ' +
      'allowfullscreen></iframe></body></html>';
    reply.type('text/html').send(html);
  }

  @Post('videos/:id/like')
  @ApiOperation({ summary: 'Like a video' })
  recordVideoLike(@Param('id') id: string) {
    return this.service.recordVideoLike(id);
  }

  @Post('audiobooks/:id/play')
  @ApiOperation({ summary: 'Record an audiobook play' })
  recordAudiobookPlay(@Param('id') id: string) {
    return this.service.recordAudiobookPlay(id);
  }

  @Post('books/:id/read')
  @ApiOperation({ summary: 'Record a book read' })
  recordBookRead(@Param('id') id: string) {
    return this.service.recordBookRead(id);
  }
}
