import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { IqService } from './iq.service';

/** Ota-ona ilovasi: bolaning IQ natijasi (savollar va javoblarsiz) — docs/IQ-REJA.md §5. */
@ApiTags('IQ (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('children/:childId/iq')
export class IqParentController {
  constructor(private readonly iq: IqService) {}

  @Get('summary')
  @ApiOperation({
    summary: 'Oxirgi natija, tarix va keyingi topshirish sanasi',
  })
  async summary(@CurrentUser() user: JwtPayload, @Param('childId', ParseUUIDPipe) childId: string) {
    await this.iq.assertParentOwns(user.userId, childId);
    return this.iq.parentSummary(childId);
  }
}
