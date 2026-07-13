import {
  Body,
  Controller,
  Get,
  Post,
  Put,
  Delete,
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

  @Get('articles')
  @ApiOperation({ summary: 'List articles (age filtered, approved)' })
  getArticles(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getArticles(
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
  // header'siz ishlaydi. Xom signed MinIO URL telefonga yetib bo'lmaydi,
  // shuning uchun backend orqali proxy. storageKey uuid = capability.
  //
  // Ovozli/video xabarlar bilan BIR XIL isbotlangan pattern: StreamableFile
  // (200, to'liq buffer) — just_audio/ExoPlayer bola'da aynan shu bilan
  // o'ynaydi (voice/video-messages shunday ishlaydi; Range @Res yo'li bola'da
  // 0:00 da qotardi). Content-Type'ni fayl kengaytmasidan ANIQLAYMIZ: admin
  // audio'ni ishonchsiz MIME bilan (octet-stream / audio/x-m4a) yuklagani
  // uchun player formatni topolmasdi.
  @Get('media/:segment/:file')
  @Public()
  @ApiOperation({ summary: 'Stream content media (Range-aware proxy)' })
  async streamMedia(
    @Param('segment') segment: string,
    @Param('file') file: string,
    @Req() req: FastifyRequest,
    @Res() reply: FastifyReply,
  ) {
    // HTTP Range qo'llab-quvvatlaymiz: ExoPlayer/just_audio audio/video'da
    // seek (oldinga/orqaga) uchun Range so'rovi yuboradi va M4A moov atom'ni
    // o'qish uchun ham kerak. Range bo'lsa MinIO 206 (Content-Range) qaytaradi.
    const range = req.headers.range;
    const obj = await this.service.getMediaStream(segment, file, range);
    reply.header('Accept-Ranges', 'bytes');
    reply.header('Cache-Control', 'public, max-age=86400');
    // Content-Type'ni fayl kengaytmasidan ANIQLAYMIZ — admin ishonchsiz MIME
    // (octet-stream / audio/x-m4a) bilan yuklasa player formatni topolmasdi.
    reply.type(this.contentTypeFor(segment, file, obj.contentType));
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

  private contentTypeFor(
    segment: string,
    file: string,
    stored?: string,
  ): string {
    // 1) Fayl kengaytmasi ANIQ manba — admin MIME'si ishonchsiz (octet-stream
    //    yoki audio/x-m4a kabi), shuning uchun kengaytmaga ustunlik beramiz.
    const ext = file.includes('.')
      ? (file.split('.').pop()?.toLowerCase() ?? '')
      : '';
    const byExt = ConsumerContentController.MIME[ext];
    if (byExt) return byExt;
    // 2) Saqlangan tur ishonchli (octet emas) bo'lsa — o'shani.
    if (stored && stored !== 'application/octet-stream') return stored;
    // 3) Kengaytma yo'q + ishonchsiz stored — segment bo'yicha default
    //    (admin audiokitoblari m4a/mp4, videolar mp4).
    if (segment === 'audio') return 'audio/mp4';
    if (segment === 'video') return 'video/mp4';
    return 'application/octet-stream';
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
    // MUHIM (Xato 153 fix): AVVAL `enablejsapi=1&origin=...` ishlatilardi —
    // bu YouTube'ni QAT'IY origin tekshiruviga majburlaydi va WebView'ning
    // haqiqiy referer'i origin param bilan to'liq mos kelmasa "Xato 153"
    // ("Videopleyerni sozlashda xatolik") beradi. Biz JS API (postMessage
    // player control) ishlatmaymiz, shuning uchun `enablejsapi`'ni OLIB
    // TASHLADIK → qat'iy tekshiruv yo'q, embed oddiy ishlaydi.
    //
    // ASOSIY SABAB (nihoyat): butun ilova `@fastify/helmet` bilan o'raldi va
    // uning STANDART sozlamasi har bir javobga `Referrer-Policy: no-referrer`
    // header'ini qo'shadi. Android WebView iframe'dagi `referrerpolicy`
    // atributini va `<meta name=referrer>` ni ko'pincha E'TIBORSIZ qoldirib,
    // faqat HTTP `Referrer-Policy` header'iga amal qiladi → referer butunlay
    // o'chiriladi → YouTube embed "Xato 153" beradi. Shuning uchun SHU route'da
    // helmet header'ini OCHIQ ravishda bekor qilamiz: YouTube embedlovchi
    // origin'ni (https://farzandimedu.uz) ko'rishi uchun referer yuboramiz.
    reply.header('Referrer-Policy', 'strict-origin-when-cross-origin');
    // youtube-nocookie.com — privacy-host, embed cheklovlariga yumshoqroq
    // (153/150 kamroq chiqadi), aks holda www.youtube.com bilan bir xil.
    const src =
      `https://www.youtube-nocookie.com/embed/${id}` +
      `?playsinline=1&rel=0&modestbranding=1&fs=1`;
    const html =
      '<!DOCTYPE html><html><head>' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,' +
      'maximum-scale=1,user-scalable=no">' +
      '<meta name="referrer" content="strict-origin-when-cross-origin">' +
      '<style>html,body{margin:0;background:#000;height:100%;overflow:hidden}' +
      'iframe{position:fixed;top:0;left:0;width:100%;height:100%;border:0}' +
      '</style></head><body>' +
      `<iframe src="${src}" ` +
      'referrerpolicy="strict-origin-when-cross-origin" ' +
      'allow="autoplay;encrypted-media;picture-in-picture;fullscreen" ' +
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

  @Post('audiobooks/:id/complete')
  @ApiOperation({ summary: 'Audiobook fully listened → award DON (idempotent)' })
  completeAudiobook(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.completeAudiobook(user.userId, id);
  }

  @Post('videos/:id/complete')
  @ApiOperation({ summary: 'Video fully watched → award DON (idempotent)' })
  completeVideo(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.completeVideo(user.userId, id);
  }

  @Post('books/:id/read')
  @ApiOperation({ summary: 'Record a book read' })
  recordBookRead(@Param('id') id: string) {
    return this.service.recordBookRead(id);
  }

  @Post('articles/:id/read')
  @ApiOperation({ summary: 'Record an article read (views++)' })
  recordArticleRead(@Param('id') id: string) {
    return this.service.recordArticleRead(id);
  }

  // ── Bola video engagement: ko'rish tarixi + yoqtirilganlar ────────────────

  @Post('videos/:id/history')
  @ApiOperation({ summary: 'Record that the current child watched this video' })
  recordVideoHistory(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.recordVideoHistory(user.userId, id);
  }

  @Get('history/videos')
  @ApiOperation({ summary: "Current child's watch history (newest first)" })
  getVideoHistory(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getVideoHistory(user.userId, requestOrigin(req));
  }

  @Put('videos/:id/favorite')
  @ApiOperation({ summary: 'Add a video to the current child favorites' })
  addVideoFavorite(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.addVideoFavorite(user.userId, id);
  }

  @Delete('videos/:id/favorite')
  @ApiOperation({ summary: 'Remove a video from the current child favorites' })
  removeVideoFavorite(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.removeVideoFavorite(user.userId, id);
  }

  @Get('favorites/videos')
  @ApiOperation({ summary: "Current child's favorite videos (newest first)" })
  getFavoriteVideos(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.getFavoriteVideos(user.userId, requestOrigin(req));
  }

  @Get('favorites/ids')
  @ApiOperation({ summary: "Current child's favorite video ids (feed sync)" })
  getFavoriteVideoIds(@CurrentUser() user: JwtPayload) {
    return this.service.getFavoriteVideoIds(user.userId);
  }
}
