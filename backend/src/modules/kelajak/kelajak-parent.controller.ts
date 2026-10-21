import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { KelajakInsightsService } from './kelajak-insights.service';
import { KelajakService } from './kelajak.service';

/** Ota-ona ilovasi: bolaning Kelajak xulosasi (javoblar va ochiq matnsiz). */
@ApiTags('Kelajak (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('children/:childId/kelajak')
export class KelajakParentController {
  constructor(
    private readonly kelajak: KelajakService,
    private readonly insights: KelajakInsightsService,
  ) {}

  @Get('summary')
  @ApiOperation({ summary: 'Qiziqishlar, kuchli tomonlar, rivojlanish, Career Lab, signal va progress' })
  async summary(@CurrentUser() user: JwtPayload, @Param('childId', ParseUUIDPipe) childId: string) {
    await this.kelajak.assertParentOwns(user.userId, childId);
    return this.insights.parentSummary(childId);
  }
}
