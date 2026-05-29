import {
  Controller,
  Get,
  Post,
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
import { AppUsageService } from './app-usage.service';
import { BatchUpsertUsageDto } from './dto/batch-upsert-usage.dto';
import { ListAppUsageDto } from './dto/list-app-usage.dto';
import { Request } from 'express';

@ApiTags('App Usage')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class AppUsageController {
  constructor(private readonly service: AppUsageService) {}

  @Post('children/:childId/app-usage')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Batch upsert app usage data' })
  batchUpsert(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: BatchUpsertUsageDto,
    @Req() req: Request,
  ) {
    return this.service.batchUpsert(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('children/:childId/app-usage')
  @ApiOperation({ summary: 'List app usage for a child' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListAppUsageDto,
  ) {
    return this.service.list(childId, user.userId, query);
  }

  @Get('children/:childId/app-usage/weekly')
  @ApiOperation({ summary: 'Get 7-day usage chart data for a child' })
  weekly(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.weekly(childId, user.userId);
  }
}
