import { Controller, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ChildAnnouncementsService } from './child-announcements.service';

/** Parvoz Growth bola ilovasi: maktab e'lonlari ("o'quvchilarga ham" belgilanganlar). */
@ApiTags('School comms (child)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/announcements')
export class ChildAnnouncementsController {
  constructor(private readonly announcements: ChildAnnouncementsService) {}

  @Get()
  @ApiOperation({ summary: "Menga ko'rinadigan e'lonlar (kursor bilan) + o'qilmaganlar soni" })
  list(@CurrentUser() user: JwtPayload, @Query() query: Record<string, unknown>) {
    return this.announcements.list(user.userId, query);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "E'lon o'qildi (idempotent)" })
  read(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.announcements.markRead(user.userId, id);
  }
}
