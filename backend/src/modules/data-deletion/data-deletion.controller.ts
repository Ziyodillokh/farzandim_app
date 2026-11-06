import { Controller, Get, Param, Post, Res, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { FastifyReply } from 'fastify';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { DATA_DELETION_LIMIT, THROTTLER_NAMES } from '../../common/throttle/throttle.config';
import { UserThrottlerGuard } from '../../common/throttle/user-throttler.guard';
import { DataDeletionService } from './data-deletion.service';

@ApiTags('Data deletion requests')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('children/:childId/deletion-requests')
export class DataDeletionController {
  constructor(private readonly service: DataDeletionService) {}

  // Guard tartibi muhim: JWT avval (req.user), keyin foydalanuvchi bo'yicha limit.
  @Post()
  @Roles('CHILD')
  @Throttle({ [THROTTLER_NAMES.dataDeletion]: DATA_DELETION_LIMIT })
  @UseGuards(UserThrottlerGuard)
  @ApiOperation({ summary: "Bola o'z ma'lumotlarini o'chirishni so'raydi (hech narsa avtomatik o'chmaydi)" })
  @ApiResponse({ status: 201, description: "Yangi so'rov yaratildi" })
  @ApiResponse({ status: 200, description: "Oxirgi 30 kunda RECEIVED so'rov bor — o'sha qaytdi" })
  @ApiResponse({ status: 429, description: 'Sutkada 3 tadan ortiq so\'rov' })
  async create(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    const { created, request } = await this.service.create(childId, user.userId);
    reply.status(created ? 201 : 200);
    return request;
  }

  @Get('latest')
  @ApiOperation({ summary: "Eng so'nggi so'rov yoki null (bola yoki ota-ona)" })
  latest(@Param('childId') childId: string, @CurrentUser() user: JwtPayload) {
    return this.service.latest(childId, user.userId);
  }
}
