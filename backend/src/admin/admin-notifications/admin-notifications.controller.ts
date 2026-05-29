import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
} from '@nestjs/swagger';
import { AdminNotificationsService } from './admin-notifications.service';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('Admin - Notifications')
@ApiBearerAuth('admin-jwt')
@Controller('admin/notifications')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_notifications')
export class AdminNotificationsController {
  constructor(private readonly service: AdminNotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'List notifications' })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'audience', required: false })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  async list(
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('audience') audience?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.service.list({ q, status, audience, from, to });
  }

  @Get('history')
  @ApiOperation({ summary: 'Notification history (latest 50)' })
  async history() {
    return this.service.history();
  }

  @Get('stats')
  @ApiOperation({ summary: 'Top stat cards (today sent, delivery rate, ...)' })
  async stats() {
    return this.service.stats();
  }

  @Post('ai-generate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'AI-suggested notification templates' })
  async aiGenerate() {
    return this.service.aiGenerate();
  }

  /**
   * Port of Fastify `POST /api/admin/notifications/upload-image`.
   * Uploads a notification banner image (jpg/png/webp/gif, max 5 MB) to MinIO
   * `content-thumbnails` bucket and returns a signed URL the frontend then
   * passes back in the create-notification body as `imageUrl`.
   */
  @Post('upload-image')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiOperation({ summary: 'Upload notification image (max 5 MB)' })
  async uploadImage(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('file field required');
    return this.service.uploadImage({
      buffer: file.buffer,
      mimetype: file.mimetype,
      originalname: file.originalname,
    });
  }

  /**
   * Port of Fastify `POST /api/admin/notifications/send` — simple immediate
   * broadcast. Equivalent to creating a notification without `scheduledAt`.
   */
  @Post('send')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Send a simple immediate broadcast' })
  async send(
    @Body() dto: { title: string; message: string; target: string },
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    if (!dto?.title || !dto?.message || !dto?.target) {
      throw new BadRequestException('title, message, target are required');
    }
    return this.service.create(
      {
        title: dto.title,
        message: dto.message,
        targetType: dto.target as any,
      } as CreateNotificationDto,
      staff.sub,
      { ip: req.ip, headers: req.headers },
    );
  }

  /**
   * Port of Fastify `POST /api/admin/notifications/schedule` — broadcast
   * scheduled at a future timestamp.
   */
  @Post('schedule')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Schedule a notification for future delivery' })
  async schedule(
    @Body()
    dto: { title: string; message: string; target: string; scheduledAt: string },
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    if (!dto?.title || !dto?.message || !dto?.target || !dto?.scheduledAt) {
      throw new BadRequestException(
        'title, message, target, scheduledAt are required',
      );
    }
    return this.service.create(
      {
        title: dto.title,
        message: dto.message,
        targetType: dto.target as any,
        scheduledAt: dto.scheduledAt,
      } as CreateNotificationDto,
      staff.sub,
      { ip: req.ip, headers: req.headers },
    );
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create and send/schedule a notification' })
  async create(
    @Body() dto: CreateNotificationDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.create(dto, staff.sub, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get notification details with engagement curve' })
  async findOne(@Param('id') id: string) {
    return this.service.findOneWithEngagement(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete notification + in-app copies' })
  async remove(
    @Param('id') id: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.remove(id, staff.sub, {
      ip: req.ip,
      headers: req.headers,
    });
  }
}
