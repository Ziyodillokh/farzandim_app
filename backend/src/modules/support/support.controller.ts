import {
  Controller,
  Post,
  Get,
  Param,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
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
} from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { CurrentUser, Public } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { SupportService } from './support.service';

@ApiTags('Support')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller('support')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Post('attachments')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Upload a support chat attachment (multipart, 100 MB max)',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  async upload(@CurrentUser() user: JwtPayload, @Req() req: FastifyRequest) {
    const data = await (req as any).file();
    if (!data) {
      throw new BadRequestException('Fayl yuborilmadi');
    }
    const buffer = await data.toBuffer();
    return this.support.uploadAttachment(user.userId, {
      buffer,
      mimetype: data.mimetype,
      filename: data.filename,
    });
  }

  // @Public — Image.network / yuklab olish auth header'siz ishlashi uchun
  // (app-icon proxy bilan bir xil). Key `{userId}_{uuid}{ext}` — tasodifiy
  // UUID tufayli taxmin qilib bo'lmaydi (capability URL).
  @Get('attachments/:key')
  @Public()
  @Header('Cache-Control', 'private, max-age=86400')
  @ApiOperation({ summary: 'Stream a support attachment (proxy)' })
  @ApiParam({ name: 'key', description: 'Attachment key from upload response' })
  async download(@Param('key') key: string): Promise<StreamableFile> {
    const obj = await this.support.getAttachment(key);
    return new StreamableFile(obj.body, { type: obj.contentType });
  }
}
