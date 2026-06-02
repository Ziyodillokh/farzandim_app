import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
} from '@nestjs/swagger';
import { AudiobooksService, BulkAudiobookAction } from './audiobooks.service';
import { CreateAudiobookDto, UpdateAudiobookDto } from './dto/create-audiobook.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../../common/guards';
import { Permissions } from '../../../common/decorators';

@ApiTags('Admin - Content Audiobooks')
@ApiBearerAuth('admin-jwt')
@Controller('admin/audiobooks')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_content')
export class AudiobooksController {
  constructor(private readonly service: AudiobooksService) {}

  @Get()
  @ApiOperation({ summary: 'List audiobooks (paginated)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'categoryId', required: false })
  async list(
    @Query('page') page = 1,
    @Query('limit') limit = 20,
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('categoryId') categoryId?: string,
    @Query('planRequired') planRequired?: string,
    @Query('ageFrom') ageFrom?: string,
    @Query('ageTo') ageTo?: string,
  ) {
    return this.service.list({
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
      q, status, categoryId, planRequired,
      ageFrom: ageFrom ? +ageFrom : undefined,
      ageTo: ageTo ? +ageTo : undefined,
    });
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create an audiobook entry' })
  async create(@Body() dto: CreateAudiobookDto) {
    return this.service.create(dto);
  }

  /**
   * Port of Fastify `POST /admin/audiobooks/upload` — multipart MinIO upload.
   * FormData: audioFile, optional thumbnailFile, metadata JSON string.
   */
  @Post('upload')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'audioFile', maxCount: 1 },
      { name: 'thumbnailFile', maxCount: 1 },
    ]),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        audioFile: { type: 'string', format: 'binary' },
        thumbnailFile: { type: 'string', format: 'binary' },
        metadata: { type: 'string' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload audio + optional thumbnail to MinIO' })
  async upload(
    @UploadedFiles()
    files: {
      audioFile?: Express.Multer.File[];
      thumbnailFile?: Express.Multer.File[];
    },
    @Body('metadata') metadata?: string,
  ) {
    const audio = files?.audioFile?.[0];
    const thumb = files?.thumbnailFile?.[0];
    if (!audio) throw new BadRequestException('audioFile field required');
    if (!metadata) throw new BadRequestException('metadata field required');
    let meta: any;
    try {
      meta = JSON.parse(metadata);
    } catch {
      throw new BadRequestException('Invalid metadata JSON');
    }
    return this.service.upload(
      {
        buffer: audio.buffer,
        mimetype: audio.mimetype,
        originalname: audio.originalname,
      },
      thumb
        ? {
            buffer: thumb.buffer,
            mimetype: thumb.mimetype,
            originalname: thumb.originalname,
          }
        : null,
      meta,
    );
  }

  /**
   * Port of Fastify `POST /admin/audiobooks/bulk`.
   */
  @Post('bulk')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Bulk action over a list of audiobook IDs' })
  async bulk(
    @Body() dto: { ids: string[]; action: BulkAudiobookAction },
  ) {
    if (!Array.isArray(dto?.ids) || dto.ids.length === 0) {
      throw new BadRequestException('ids must be a non-empty array');
    }
    if (!dto?.action) throw new BadRequestException('action is required');
    return this.service.bulk(dto.ids, dto.action);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update an audiobook' })
  async update(@Param('id') id: string, @Body() dto: UpdateAudiobookDto) {
    return this.service.update(id, dto);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve an audiobook' })
  async approve(@Param('id') id: string) {
    return this.service.approve(id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject an audiobook' })
  async reject(@Param('id') id: string) {
    return this.service.reject(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete an audiobook' })
  async remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
