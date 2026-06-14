import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { NotificationPreferencesService } from './notification-preferences.service';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';

@ApiTags('Notification Preferences')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('children/:childId/notification-preferences')
export class NotificationPreferencesController {
  constructor(private readonly service: NotificationPreferencesService) {}

  @Get()
  @ApiOperation({ summary: 'Get nudge/reminder preferences for a child' })
  get(@Param('childId') childId: string, @CurrentUser() user: JwtPayload) {
    return this.service.get(childId, user.userId);
  }

  @Put()
  @ApiOperation({ summary: 'Update nudge/reminder preferences (parent or child)' })
  update(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.service.update(childId, user.userId, dto);
  }
}
