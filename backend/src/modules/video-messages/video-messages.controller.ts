import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  BadRequestException,
  StreamableFile,
  Header,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiConsumes,
  ApiBody,
  ApiParam,
  ApiQuery,
  ApiResponse,
} from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { CurrentUser, Public } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ParseUUIDPipe } from '../../common/pipes/parse-uuid.pipe';
import { VideoMessagesService } from './video-messages.service';
import { ListVideoMessagesDto } from './dto';

@ApiTags('Video Messages')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller('video-messages')
export class VideoMessagesController {
  constructor(private readonly videoMessagesService: VideoMessagesService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Send a video message (multipart upload, 100 MB max)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'receiverId'],
      properties: {
        file: { type: 'string', format: 'binary', description: 'Video file' },
        receiverId: { type: 'string', format: 'uuid' },
        durationSeconds: { type: 'number', description: 'Duration in seconds' },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'Video message created' })
  async send(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    const data = await (req as any).file();
    if (!data) {
      throw new BadRequestException('No file uploaded');
    }

    const buffer = await data.toBuffer();

    const fields = data.fields as Record<string, any>;
    const receiverId = fields?.receiverId?.value as string | undefined;
    const durationRaw = fields?.durationSeconds?.value;
    const durationSeconds = durationRaw ? Number(durationRaw) : undefined;

    if (!receiverId) {
      throw new BadRequestException('receiverId required');
    }

    return this.videoMessagesService.send(user.userId, receiverId, durationSeconds, {
      buffer,
      mimetype: data.mimetype,
      filename: data.filename,
    });
  }

  @Get()
  @ApiOperation({ summary: 'List video messages for the current user' })
  @ApiQuery({ name: 'role', required: false, enum: ['sent', 'received'] })
  @ApiQuery({ name: 'peerId', required: false, description: 'Only messages with this user' })
  @ApiQuery({ name: 'before', required: false, description: 'Cursor: created before this ISO date' })
  @ApiQuery({ name: 'limit', required: false, description: 'Page size (default 100, max 100)' })
  @ApiResponse({ status: 200, description: 'List of video messages' })
  async list(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListVideoMessagesDto,
  ) {
    return this.videoMessagesService.list(user.userId, query);
  }

  @Get(':id/file')
  @ApiOperation({ summary: 'Get signed download URL for a video message (1h TTL)' })
  @ApiParam({ name: 'id', description: 'Video message UUID' })
  @ApiResponse({ status: 200, description: 'Signed URL returned' })
  async getFile(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.videoMessagesService.getFileUrl(user.userId, id);
  }

  // @Public proxy stream — signed URL telefondan yetib bo'lmaydi (ichki
  // MinIO manzili). `:id` UUID = capability URL. video_player shu URL'dan
  // to'g'ridan o'ynaydi va birinchi kadr thumbnail bo'ladi.
  @Get(':id/stream')
  @Public()
  @Header('Cache-Control', 'private, max-age=86400')
  @ApiOperation({ summary: 'Stream a video message (proxy)' })
  @ApiParam({ name: 'id', description: 'Video message UUID' })
  async stream(
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<StreamableFile> {
    const obj = await this.videoMessagesService.getVideoStream(id);
    return new StreamableFile(obj.body, { type: obj.contentType });
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a video message (sender or receiver)' })
  @ApiParam({ name: 'id', description: 'Video message UUID' })
  @ApiResponse({ status: 200, description: 'Message deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.videoMessagesService.remove(user.userId, id);
  }
}
