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
import { VideosService, BulkVideoAction } from './videos.service';
import { CreateVideoDto, UpdateVideoDto } from './dto/create-video.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../../common/guards';
import { Permissions } from '../../../common/decorators';

@ApiTags('Admin - Content Videos')
@ApiBearerAuth('admin-jwt')
@Controller('admin/videos')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_content')
export class VideosController {
  constructor(private readonly service: VideosService) {}

  @Get()
  @ApiOperation({ summary: 'List videos (paginated)' })
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
    @Query('level') level?: string,
    @Query('ageFrom') ageFrom?: string,
    @Query('ageTo') ageTo?: string,
  ) {
    return this.service.list({
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
      q,
      status,
      categoryId,
      planRequired,
      level,
      ageFrom: ageFrom ? +ageFrom : undefined,
      ageTo: ageTo ? +ageTo : undefined,
    });
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a video entry' })
  async create(@Body() dto: CreateVideoDto) {
    return this.service.create(dto);
  }

  /**
   * Port of Fastify `POST /admin/videos/upload` — multipart MinIO upload.
   * FormData:
   *   videoFile:      main video (mp4/webm/...) — max 90 MB
   *   thumbnailFile?: cover image (jpg/png/webp/gif) — max 5 MB
   *   metadata:       JSON string with the CreateVideoDto fields
   */
  @Post('upload')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'videoFile', maxCount: 1 },
      { name: 'thumbnailFile', maxCount: 1 },
    ]),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        videoFile: { type: 'string', format: 'binary' },
        thumbnailFile: { type: 'string', format: 'binary' },
        metadata: { type: 'string' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload a video + optional thumbnail to MinIO' })
  async upload(
    @UploadedFiles()
    files: {
      videoFile?: Express.Multer.File[];
      thumbnailFile?: Express.Multer.File[];
    },
    @Body('metadata') metadata?: string,
  ) {
    const video = files?.videoFile?.[0];
    const thumb = files?.thumbnailFile?.[0];
    if (!video) throw new BadRequestException('videoFile field required');
    if (!metadata) throw new BadRequestException('metadata field required');
    let meta: any;
    try {
      meta = JSON.parse(metadata);
    } catch {
      throw new BadRequestException('Invalid metadata JSON');
    }
    return this.service.upload(
      {
        buffer: video.buffer,
        mimetype: video.mimetype,
        originalname: video.originalname,
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
   * Port of Fastify `POST /admin/videos/bulk` — multi-action over a list of
   * video IDs.
   */
  @Post('bulk')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Bulk action over a list of video IDs' })
  async bulk(
    @Body() dto: { ids: string[]; action: BulkVideoAction },
  ) {
    if (!Array.isArray(dto?.ids) || dto.ids.length === 0) {
      throw new BadRequestException('ids must be a non-empty array');
    }
    if (!dto?.action) {
      throw new BadRequestException('action is required');
    }
    return this.service.bulk(dto.ids, dto.action);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a video' })
  async update(@Param('id') id: string, @Body() dto: UpdateVideoDto) {
    return this.service.update(id, dto);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a video' })
  async approve(@Param('id') id: string) {
    return this.service.approve(id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a video' })
  async reject(@Param('id') id: string) {
    return this.service.reject(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a video' })
  async remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
