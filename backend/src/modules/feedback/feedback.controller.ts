import {
  Controller,
  Get,
  Post,
  Put,
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
import { FeedbackService } from './feedback.service';
import { CreateFeedbackDto, ListFeedbackDto } from './dto';

@ApiTags('Feedback')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller()
export class FeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  @Get('children/:childId/feedback')
  @ApiOperation({ summary: 'List feedback for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiQuery({ name: 'isRead', required: false, enum: ['true', 'false'] })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results (1-200, default 100)' })
  @ApiResponse({ status: 200, description: 'List of feedback entries' })
  async listByChild(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Query() query: ListFeedbackDto,
  ) {
    return this.feedbackService.listByChild(user.userId, childId, query);
  }

  @Post('children/:childId/feedback')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create feedback for a child (child or parent)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 201, description: 'Feedback created' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: CreateFeedbackDto,
    @Req() req: FastifyRequest,
  ) {
    return this.feedbackService.create(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Put('feedback/:id/read')
  @ApiOperation({ summary: 'Mark feedback as read (parent only)' })
  @ApiParam({ name: 'id', description: 'Feedback UUID' })
  @ApiResponse({ status: 200, description: 'Feedback marked as read' })
  async markAsRead(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.feedbackService.markAsRead(user.userId, id);
  }
}
