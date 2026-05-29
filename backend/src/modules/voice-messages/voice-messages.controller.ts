import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Param,
  Query,
  Body,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  BadRequestException,
  UnsupportedMediaTypeException,
  PayloadTooLargeException,
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
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ParseUUIDPipe } from '../../common/pipes/parse-uuid.pipe';
import { VoiceMessagesService } from './voice-messages.service';
import { ListVoiceMessagesDto, ReadAllVoiceMessagesDto } from './dto';

@ApiTags('Voice Messages')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller('voice-messages')
export class VoiceMessagesController {
  constructor(private readonly voiceMessagesService: VoiceMessagesService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Send a voice message (multipart upload, 10 MB max)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'receiverId'],
      properties: {
        file: { type: 'string', format: 'binary', description: 'Audio file' },
        receiverId: { type: 'string', format: 'uuid' },
        durationSeconds: { type: 'number', description: 'Duration in seconds' },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'Voice message created' })
  async send(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    const data = await (req as any).file();
    if (!data) {
      throw new BadRequestException('No file uploaded');
    }

    const buffer = await data.toBuffer();

    // Extract form fields
    const fields = data.fields as Record<string, any>;
    const receiverId = fields?.receiverId?.value as string | undefined;
    const durationRaw = fields?.durationSeconds?.value;
    const durationSeconds = durationRaw ? Number(durationRaw) : undefined;

    if (!receiverId) {
      throw new BadRequestException('receiverId required');
    }

    return this.voiceMessagesService.send(user.userId, receiverId, durationSeconds, {
      buffer,
      mimetype: data.mimetype,
      filename: data.filename,
    });
  }

  @Get()
  @ApiOperation({ summary: 'List voice messages for the current user' })
  @ApiQuery({ name: 'role', required: false, enum: ['sent', 'received'] })
  @ApiResponse({ status: 200, description: 'List of voice messages' })
  async list(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListVoiceMessagesDto,
  ) {
    return this.voiceMessagesService.list(user.userId, query.role);
  }

  @Get(':id/file')
  @ApiOperation({ summary: 'Get signed download URL for a voice message (1h TTL)' })
  @ApiParam({ name: 'id', description: 'Voice message UUID' })
  @ApiResponse({ status: 200, description: 'Signed URL returned' })
  async getFile(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.voiceMessagesService.getFileUrl(user.userId, id);
  }

  @Put(':id/read')
  @ApiOperation({ summary: 'Mark a voice message as read (receiver only)' })
  @ApiParam({ name: 'id', description: 'Voice message UUID' })
  @ApiResponse({ status: 200, description: 'Message marked as read' })
  async markAsRead(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.voiceMessagesService.markAsRead(user.userId, id);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Bulk mark all received voice messages as read' })
  @ApiResponse({ status: 200, description: 'Count of updated messages' })
  async readAll(
    @CurrentUser() user: JwtPayload,
    @Body() body: ReadAllVoiceMessagesDto,
  ) {
    return this.voiceMessagesService.readAll(user.userId, body.fromUserId);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a voice message (sender or receiver)' })
  @ApiParam({ name: 'id', description: 'Voice message UUID' })
  @ApiResponse({ status: 200, description: 'Message deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.voiceMessagesService.remove(user.userId, id);
  }
}
