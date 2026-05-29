import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { LocationService } from './location.service';
import { WriteLocationDto } from './dto/write-location.dto';
import { LocationHistoryQueryDto } from './dto/location-history-query.dto';
import { CurrentUser } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('Location')
@ApiBearerAuth('consumer-jwt')
@Controller()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
export class LocationController {
  constructor(private readonly locationService: LocationService) {}

  @Post('location')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Write GPS location (with 10m dedup + geofence detection + push alerts)',
  })
  @ApiResponse({
    status: 200,
    description: 'Location written (or skipped if too close)',
  })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async writeLocation(
    @CurrentUser() user: JwtPayload,
    @Body() dto: WriteLocationDto,
  ) {
    return this.locationService.writeLocation(user.userId, dto);
  }

  @Get('children/:childId/location')
  @ApiOperation({ summary: 'Get last known location for a child' })
  @ApiParam({ name: 'childId', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Last location + child device info' })
  @ApiResponse({ status: 404, description: 'Child or location not found' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  async getLastLocation(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.locationService.getLastLocation(childId, user.userId);
  }

  @Get('children/:childId/location/history')
  @ApiOperation({ summary: 'Get location history for a child' })
  @ApiParam({ name: 'childId', description: 'Child ID (UUID)' })
  @ApiQuery({ name: 'from', required: false, description: 'Start date (ISO 8601)' })
  @ApiQuery({ name: 'to', required: false, description: 'End date (ISO 8601)' })
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Max records (1-500, default 100)',
  })
  @ApiResponse({ status: 200, description: 'Array of locations' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async getLocationHistory(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: LocationHistoryQueryDto,
  ) {
    return this.locationService.getLocationHistory(
      childId,
      user.userId,
      query,
    );
  }
}
