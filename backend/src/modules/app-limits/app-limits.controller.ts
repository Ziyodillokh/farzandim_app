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
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AppLimitsService } from './app-limits.service';
import { CreateAppLimitDto } from './dto/create-app-limit.dto';
import { UpdateAppLimitDto } from './dto/update-app-limit.dto';
import { ListAppLimitsDto } from './dto/list-app-limits.dto';
import { Request } from 'express';

@ApiTags('App Limits')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class AppLimitsController {
  constructor(private readonly service: AppLimitsService) {}

  @Get('children/:childId/app-limits')
  @ApiOperation({ summary: 'List app limits for a child' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListAppLimitsDto,
  ) {
    return this.service.list(childId, user.userId, query.isActive);
  }

  @Post('children/:childId/app-limits')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create app limit (parent only)' })
  create(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateAppLimitDto,
    @Req() req: Request,
  ) {
    return this.service.create(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('app-limits/:id')
  @ApiOperation({ summary: 'Get a single app limit' })
  findOne(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.findOne(id, user.userId);
  }

  @Put('app-limits/:id')
  @ApiOperation({ summary: 'Update app limit (parent only)' })
  update(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateAppLimitDto,
    @Req() req: Request,
  ) {
    return this.service.update(id, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Delete('app-limits/:id')
  @ApiOperation({ summary: 'Delete app limit (parent only)' })
  remove(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.remove(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
