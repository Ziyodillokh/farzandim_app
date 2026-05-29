import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminOlympiadsService } from './admin-olympiads.service';
import { CreateOlympiadDto, QuestionDto } from './dto/create-olympiad.dto';
import { UpdateOlympiadDto } from './dto/update-olympiad.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

@ApiTags('Admin - Olympiads')
@ApiBearerAuth('admin-jwt')
@Controller('admin/olympiads')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_olympiads')
export class AdminOlympiadsController {
  constructor(private readonly service: AdminOlympiadsService) {}

  @Get()
  @ApiOperation({ summary: 'List olympiads (paginated)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'subject', required: false })
  async list(
    @Query('page') page = 1,
    @Query('limit') limit = 20,
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('subject') subject?: string,
    @Query('ageFrom') ageFrom?: string,
    @Query('ageTo') ageTo?: string,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
  ) {
    return this.service.list({
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
      q,
      status,
      subject,
      ageFrom: ageFrom !== undefined ? +ageFrom : undefined,
      ageTo: ageTo !== undefined ? +ageTo : undefined,
      dateFrom,
      dateTo,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get olympiad detail with questions' })
  async findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create an olympiad' })
  async create(@Body() dto: CreateOlympiadDto) {
    return this.service.create(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update an olympiad' })
  async update(@Param('id') id: string, @Body() dto: UpdateOlympiadDto) {
    return this.service.update(id, dto);
  }

  @Post(':id/publish')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Publish an olympiad' })
  async publish(@Param('id') id: string) {
    return this.service.publish(id);
  }

  @Post(':id/archive')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Archive an olympiad' })
  async archive(@Param('id') id: string) {
    return this.service.archive(id);
  }

  @Post(':id/unpublish')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unpublish (revert to draft)' })
  async unpublish(@Param('id') id: string) {
    return this.service.unpublish(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete an olympiad' })
  async remove(@Param('id') id: string) {
    await this.service.remove(id);
  }

  @Get(':id/participants')
  @ApiOperation({ summary: 'List olympiad participants' })
  async participants(@Param('id') id: string) {
    return this.service.participants(id);
  }

  @Get(':id/leaderboard')
  @ApiOperation({ summary: 'Olympiad leaderboard (paginated)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async leaderboard(
    @Param('id') id: string,
    @Query('page') page = 1,
    @Query('limit') limit = 200,
  ) {
    return this.service.leaderboard(id, +page || 1, +limit || 200);
  }

  @Post(':id/questions')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a question to an olympiad' })
  async addQuestion(@Param('id') id: string, @Body() dto: QuestionDto) {
    return this.service.addQuestion(id, dto);
  }

  @Patch(':id/questions/:qid')
  @ApiOperation({ summary: 'Update a question' })
  async updateQuestion(
    @Param('id') id: string,
    @Param('qid') qid: string,
    @Body() dto: Partial<QuestionDto>,
  ) {
    return this.service.updateQuestion(id, qid, dto);
  }

  @Delete(':id/questions/:qid')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a question' })
  async deleteQuestion(@Param('id') id: string, @Param('qid') qid: string) {
    return this.service.deleteQuestion(id, qid);
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Olympiad participation stats and leaderboard' })
  async getStats(@Param('id') id: string) {
    return this.service.getStats(id);
  }
}
