import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AdminLearningService } from './admin-learning.service';
import {
  ImportLearningQuestionsDto,
  LearningQuestionInputDto,
  ListLearningQuestionsQueryDto,
  UpdateLearningQuestionDto,
} from './dto/admin-learning.dto';

@ApiTags('Admin - Learning')
@ApiBearerAuth('admin-jwt')
@Controller('admin/learning')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_learning')
export class AdminLearningController {
  constructor(private readonly service: AdminLearningService) {}

  @Get('questions')
  @ApiOperation({ summary: 'Savollar (filtr, qidiruv, aniqlik statistikasi bilan)' })
  list(@Query() query: ListLearningQuestionsQueryDto) {
    return this.service.list(query);
  }

  @Get('questions/:id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.get(id);
  }

  @Post('questions')
  @ApiOperation({ summary: 'Savol qo\'shish' })
  create(
    @Body() dto: LearningQuestionInputDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.create(dto, staff.sub, req);
  }

  @Patch('questions/:id')
  @ApiOperation({ summary: 'Tahrirlash (javob berilgan savolda to\'g\'ri javob o\'zgarmaydi)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateLearningQuestionDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.update(id, dto, staff.sub, req);
  }

  @Delete('questions/:id')
  @ApiOperation({ summary: 'O\'chirish (javob berilgan bo\'lsa — arxivlash)' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.remove(id, staff.sub, req);
  }

  @Post('questions/import')
  @ApiOperation({ summary: 'Bank formatidagi JSON import (externalId bo\'yicha)' })
  import(
    @Body() dto: ImportLearningQuestionsDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.import(dto, staff.sub, req);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Bank holati, urinishlar va savol aniqligi' })
  stats() {
    return this.service.stats();
  }
}
