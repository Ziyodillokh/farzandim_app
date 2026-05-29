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
import { RoutinesService } from './routines.service';
import { CreateRoutineDto, UpdateRoutineDto } from './dto';

@ApiTags('Routines')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller()
export class RoutinesController {
  constructor(private readonly routinesService: RoutinesService) {}

  @Get('children/:childId/routines')
  @ApiOperation({ summary: 'List all routines for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 200, description: 'List of routines' })
  async listByChild(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    return this.routinesService.listByChild(user.userId, childId);
  }

  @Get('children/:childId/routines/today')
  @ApiOperation({ summary: 'Get today active routines with current/next info (Tashkent TZ)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 200, description: 'Today routines with current and next' })
  async getToday(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    return this.routinesService.getToday(user.userId, childId);
  }

  @Post('children/:childId/routines')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a routine for a child (parent only)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 201, description: 'Routine created' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: CreateRoutineDto,
    @Req() req: FastifyRequest,
  ) {
    return this.routinesService.create(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('routines/:id')
  @ApiOperation({ summary: 'Get a single routine' })
  @ApiParam({ name: 'id', description: 'Routine UUID' })
  @ApiResponse({ status: 200, description: 'Routine details' })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.routinesService.findOne(user.userId, id);
  }

  @Put('routines/:id')
  @ApiOperation({ summary: 'Update a routine (parent only)' })
  @ApiParam({ name: 'id', description: 'Routine UUID' })
  @ApiResponse({ status: 200, description: 'Routine updated' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRoutineDto,
    @Req() req: FastifyRequest,
  ) {
    return this.routinesService.update(user.userId, id, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Delete('routines/:id')
  @ApiOperation({ summary: 'Delete a routine (parent only)' })
  @ApiParam({ name: 'id', description: 'Routine UUID' })
  @ApiResponse({ status: 200, description: 'Routine deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: FastifyRequest,
  ) {
    return this.routinesService.remove(user.userId, id, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
