import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
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
  ApiResponse,
} from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ParseUUIDPipe } from '../../common/pipes/parse-uuid.pipe';
import { SchedulesService } from './schedules.service';
import { CreateScheduleDto, UpdateScheduleDto } from './dto';

@ApiTags('Schedules')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller()
export class SchedulesController {
  constructor(private readonly schedulesService: SchedulesService) {}

  @Get('children/:childId/schedules')
  @ApiOperation({ summary: 'List schedules for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 200, description: 'List of schedules' })
  async listByChild(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    return this.schedulesService.listByChild(user.userId, childId);
  }

  @Post('children/:childId/schedules')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a schedule for a child (parent only)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 201, description: 'Schedule created' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: CreateScheduleDto,
    @Req() req: FastifyRequest,
  ) {
    return this.schedulesService.create(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('schedules/:id')
  @ApiOperation({ summary: 'Get a single schedule' })
  @ApiParam({ name: 'id', description: 'Schedule UUID' })
  @ApiResponse({ status: 200, description: 'Schedule details' })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.schedulesService.findOne(user.userId, id);
  }

  @Put('schedules/:id')
  @ApiOperation({ summary: 'Update a schedule (parent only)' })
  @ApiParam({ name: 'id', description: 'Schedule UUID' })
  @ApiResponse({ status: 200, description: 'Schedule updated' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateScheduleDto,
    @Req() req: FastifyRequest,
  ) {
    return this.schedulesService.update(user.userId, id, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Delete('schedules/:id')
  @ApiOperation({ summary: 'Delete a schedule (parent only)' })
  @ApiParam({ name: 'id', description: 'Schedule UUID' })
  @ApiResponse({ status: 200, description: 'Schedule deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: FastifyRequest,
  ) {
    return this.schedulesService.remove(user.userId, id, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
