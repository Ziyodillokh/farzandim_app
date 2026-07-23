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
import { GeoZonesService } from './geo-zones.service';
import { CreateGeoZoneDto, UpdateGeoZoneDto, ListGeoZoneEventsDto } from './dto';
import { PaidTierGuard } from '../../common/entitlement/paid-tier.guard';
import { RequirePaidTier } from '../../common/entitlement/require-paid-tier.decorator';

@ApiTags('Geo Zones')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller()
export class GeoZonesController {
  constructor(private readonly geoZonesService: GeoZonesService) {}

  @Get('children/:childId/geo-zones')
  @ApiOperation({ summary: 'List geo-zones for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 200, description: 'List of geo-zones' })
  async listByChild(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    return this.geoZonesService.listByChild(user.userId, childId);
  }

  // Geo-zona yaratish — lokatsiya funksiyasi, faqat pullik tarif.
  @UseGuards(PaidTierGuard)
  @RequirePaidTier()
  @Post('children/:childId/geo-zones')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a geo-zone for a child (parent only)' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiResponse({ status: 201, description: 'Geo-zone created' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: CreateGeoZoneDto,
    @Req() req: FastifyRequest,
  ) {
    return this.geoZonesService.create(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('geo-zones/:id')
  @ApiOperation({ summary: 'Get a single geo-zone' })
  @ApiParam({ name: 'id', description: 'Geo-zone UUID' })
  @ApiResponse({ status: 200, description: 'Geo-zone details' })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.geoZonesService.findOne(user.userId, id);
  }

  @UseGuards(PaidTierGuard)
  @RequirePaidTier()
  @Put('geo-zones/:id')
  @ApiOperation({ summary: 'Update a geo-zone (parent only)' })
  @ApiParam({ name: 'id', description: 'Geo-zone UUID' })
  @ApiResponse({ status: 200, description: 'Geo-zone updated' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateGeoZoneDto,
    @Req() req: FastifyRequest,
  ) {
    return this.geoZonesService.update(user.userId, id, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @UseGuards(PaidTierGuard)
  @RequirePaidTier()
  @Delete('geo-zones/:id')
  @ApiOperation({ summary: 'Delete a geo-zone (parent only)' })
  @ApiParam({ name: 'id', description: 'Geo-zone UUID' })
  @ApiResponse({ status: 200, description: 'Geo-zone deleted' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: FastifyRequest,
  ) {
    return this.geoZonesService.remove(user.userId, id, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('children/:childId/geo-zone-events')
  @ApiOperation({ summary: 'List geo-zone enter/exit events for a child' })
  @ApiParam({ name: 'childId', description: 'Child UUID' })
  @ApiQuery({ name: 'from', required: false, description: 'From datetime (ISO 8601)' })
  @ApiQuery({ name: 'to', required: false, description: 'To datetime (ISO 8601)' })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results (1-200, default 50)' })
  @ApiResponse({ status: 200, description: 'List of geo-zone events' })
  async listEvents(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Query() query: ListGeoZoneEventsDto,
  ) {
    return this.geoZonesService.listEvents(user.userId, childId, query);
  }
}
