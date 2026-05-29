import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiQuery,
  ApiResponse,
} from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ParseUUIDPipe } from '../../common/pipes/parse-uuid.pipe';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto, ListNotificationsDto } from './dto';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller()
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('children/:childId/notifications')
  @ApiOperation({ summary: 'List notifications for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiQuery({ name: 'type', required: false, enum: ['ACHIEVEMENT', 'CONTEST', 'SCHEDULE', 'PARENT_REQUEST', 'VOICE', 'GEO_ZONE', 'SYSTEM'] })
  @ApiQuery({ name: 'isRead', required: false, enum: ['true', 'false'] })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results (1-200, default 100)' })
  @ApiResponse({ status: 200, description: 'List of notifications with unread count' })
  async listByChild(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Query() query: ListNotificationsDto,
  ) {
    return this.notificationsService.listByChild(user.userId, childId, query);
  }

  @Post('children/:childId/notifications')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a notification for a child (parent only)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 201, description: 'Notification created' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: CreateNotificationDto,
    @Req() req: FastifyRequest,
  ) {
    return this.notificationsService.create(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Put('notifications/:id/read')
  @ApiOperation({ summary: 'Mark a notification as read' })
  @ApiParam({ name: 'id', description: 'Notification UUID' })
  @ApiResponse({ status: 200, description: 'Notification marked as read' })
  async markAsRead(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notificationsService.markAsRead(user.userId, id);
  }

  @Post('notifications/:id/click')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Track notification deep-link click (first click only)' })
  @ApiParam({ name: 'id', description: 'Notification UUID' })
  @ApiResponse({ status: 200, description: 'Click tracked' })
  async click(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notificationsService.click(user.userId, id);
  }

  @Put('children/:childId/notifications/read-all')
  @ApiOperation({ summary: 'Mark all notifications as read for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 200, description: 'All notifications marked as read' })
  async readAll(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    return this.notificationsService.readAll(user.userId, childId);
  }

  @Delete('notifications/:id')
  @ApiOperation({ summary: 'Delete a notification' })
  @ApiParam({ name: 'id', description: 'Notification UUID' })
  @ApiResponse({ status: 200, description: 'Notification deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: FastifyRequest,
  ) {
    return this.notificationsService.remove(user.userId, id, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
