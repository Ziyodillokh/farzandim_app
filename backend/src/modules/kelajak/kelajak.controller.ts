import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { KelajakAnswerDto, KelajakResultsQueryDto, StartKelajakSessionDto } from './dto/kelajak.dto';
import { KelajakInsightsService } from './kelajak-insights.service';
import { KelajakService } from './kelajak.service';

/** Bola ilovasi: Parvoz Kelajak testlari, natijalar va profil. */
@ApiTags('Kelajak (child)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('kelajak')
export class KelajakController {
  constructor(
    private readonly kelajak: KelajakService,
    private readonly insights: KelajakInsightsService,
  ) {}

  @Get('overview')
  @ApiOperation({ summary: 'Yosh holati, bugungi testlar, kategoriyalar va kumulyativ profil' })
  async overview(@CurrentUser() user: JwtPayload) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.insights.overview(childId);
  }

  @Post('sessions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Bugungi sessiya (yangi, davom etayotgan yoki yakunlangan)' })
  async start(@CurrentUser() user: JwtPayload, @Body() dto: StartKelajakSessionDto) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.kelajak.startSession(childId, dto.type);
  }

  @Get('sessions/:id')
  @ApiOperation({ summary: 'Sessiya: savollar, berilgan javoblar va natija' })
  async session(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.kelajak.sessionView(childId, id);
  }

  @Put('sessions/:id/answers/:questionId')
  @ApiOperation({ summary: 'Javobni saqlash yoki o\'zgartirish (text: "" — o\'chirish)' })
  async answer(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('questionId', ParseUUIDPipe) questionId: string,
    @Body() dto: KelajakAnswerDto,
  ) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.kelajak.answer(childId, id, questionId, dto);
  }

  @Post('sessions/:id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Yakunlash — natija bilan (idempotent)' })
  async complete(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.kelajak.complete(childId, id);
  }

  @Get('progress')
  @ApiOperation({ summary: 'Kategoriya va qiziqishlar o\'zgarishi, tarix' })
  async progress(@CurrentUser() user: JwtPayload) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.insights.progress(childId);
  }

  @Get('results')
  @ApiOperation({ summary: 'Yakunlangan sessiyalar (yangisi birinchi, kursor bilan)' })
  async results(@CurrentUser() user: JwtPayload, @Query() query: KelajakResultsQueryDto) {
    const childId = await this.kelajak.childIdForUser(user.userId);
    return this.insights.results(childId, query);
  }
}
