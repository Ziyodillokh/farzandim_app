import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AdminKelajakService } from './admin-kelajak.service';
import {
  CreateKelajakQuestionDto,
  ListKelajakQuestionsQueryDto,
  UpdateKelajakQuestionDto,
} from './dto/admin-kelajak.dto';

/** Parvoz Kelajak savollar banki — Daily Learning bilan bir xil ruxsat. */
@ApiTags('Admin - Kelajak')
@ApiBearerAuth('admin-jwt')
@Controller('admin/kelajak')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_learning')
export class AdminKelajakController {
  constructor(private readonly service: AdminKelajakService) {}

  @Get('questions')
  @ApiOperation({ summary: 'Savollar (filtr, qidiruv, javoblar soni bilan)' })
  list(@Query() query: ListKelajakQuestionsQueryDto) {
    return this.service.list(query);
  }

  @Get('questions/:id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.get(id);
  }

  @Post('questions')
  @ApiOperation({ summary: 'Savol qo\'shish (externalId berilmasa ADMIN-xxxxxxxx)' })
  create(
    @Body() dto: CreateKelajakQuestionDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.create(dto, staff.sub, req);
  }

  @Patch('questions/:id')
  @ApiOperation({ summary: 'Tahrirlash (javob berilgan savolda faqat matn, izohlar, majburiylik va faollik)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateKelajakQuestionDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.update(id, dto, staff.sub, req);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Bank holati (kategoriya, yosh, javob turi) va sessiyalar' })
  stats() {
    return this.service.stats();
  }
}
