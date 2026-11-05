import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
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
import { AdminLearningTopicsService } from './admin-learning-topics.service';
import { AdminLearningService } from './admin-learning.service';
import {
  CreateLearningTopicDto,
  LinkTopicQuestionsDto,
  ListLearningTopicsQueryDto,
  ReorderLearningTopicsDto,
  UpdateLearningTopicDto,
} from './dto/admin-learning-topic.dto';
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
  constructor(
    private readonly service: AdminLearningService,
    private readonly topics: AdminLearningTopicsService,
  ) {}

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

  // ── Mavzular katalogi ──────────────────────────────────────────────

  @Get('topics')
  @ApiOperation({ summary: 'Mavzular (fan, holat filtri; faol savollar soni bilan)' })
  listTopics(@Query() query: ListLearningTopicsQueryDto) {
    return this.topics.list(query);
  }

  @Post('topics')
  @ApiOperation({ summary: 'Mavzu qo\'shish' })
  createTopic(
    @Body() dto: CreateLearningTopicDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.topics.create(dto, staff.sub, req);
  }

  // `reorder` — `:id` yo'llaridan oldin (statik yo'l ustun).
  @Post('topics/reorder')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Fan mavzularini qayta tartiblash (ids = fanning barcha mavzulari)' })
  reorderTopics(
    @Body() dto: ReorderLearningTopicsDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.topics.reorder(dto, staff.sub, req);
  }

  @Patch('topics/:id')
  @ApiOperation({ summary: 'Mavzuni tahrirlash (o\'chirish yo\'q: status HIDDEN)' })
  updateTopic(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateLearningTopicDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.topics.update(id, dto, staff.sub, req);
  }

  @Post('topics/:id/questions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Savollarni mavzuga bog\'lash (bir fan)' })
  linkTopicQuestions(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: LinkTopicQuestionsDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.topics.linkQuestions(id, dto, staff.sub, req);
  }
}
