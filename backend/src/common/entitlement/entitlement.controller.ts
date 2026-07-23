import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard } from '../guards';
import { CurrentUser } from '../decorators';
import { JwtPayload } from '../interfaces/jwt-payload.interface';
import { EntitlementService } from './entitlement.service';

@ApiTags('entitlement')
@Controller('me')
@UseGuards(ConsumerJwtAuthGuard)
export class EntitlementController {
  constructor(private readonly entitlement: EntitlementService) {}

  /**
   * Joriy foydalanuvchi tarifi + yoqilgan funksiyalar. Ota-ona/bola ilovasi
   * shu bilan UI'ni gate qiladi (qulflangan funksiyalarga "yuksalting" oynasi).
   */
  @Get('entitlement')
  @ApiOperation({ summary: 'Joriy foydalanuvchi tarifi va funksiyalari' })
  async getEntitlement(@CurrentUser() user: JwtPayload) {
    return this.entitlement.getEntitlement(user.userId);
  }
}
