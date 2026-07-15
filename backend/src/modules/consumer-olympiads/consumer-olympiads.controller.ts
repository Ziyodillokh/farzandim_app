import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ConsumerOlympiadsService } from './consumer-olympiads.service';
import { SubmitAttemptDto } from './dto/submit-attempt.dto';
import { RankingQueryDto } from './dto/ranking-query.dto';
import { SingleAnswerDto } from './dto/single-answer.dto';

@ApiTags('Consumer Olympiads')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('content/olympiads')
export class ConsumerOlympiadsController {
  constructor(private readonly service: ConsumerOlympiadsService) {}

  @Get()
  @ApiOperation({ summary: 'List published olympiads (age filtered)' })
  list(@CurrentUser() user: JwtPayload) {
    return this.service.listOlympiads(user.userId);
  }

  @Get('ranking')
  @ApiOperation({
    summary: 'Olympiad ranking (global yoki viloyat bo\'yicha)',
  })
  ranking(
    @CurrentUser() user: JwtPayload,
    @Query() query: RankingQueryDto,
  ) {
    return this.service.getRanking(
      user.userId,
      query.range ?? 'all',
      query.limit ?? 50,
      query.region,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Olympiad detail with questions' })
  detail(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getOlympiadDetail(user.userId, id);
  }

  @Post(':id/start')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Start an olympiad attempt' })
  start(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.startAttempt(user.userId, id);
  }

  @Post('attempts/:id/answer')
  @ApiOperation({ summary: 'Answer a single question (anti-cheat)' })
  answer(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: SingleAnswerDto,
  ) {
    return this.service.answerQuestion(
      user.userId,
      id,
      dto.questionId,
      dto.selectedIndex,
    );
  }

  @Post('attempts/:id/submit')
  @ApiOperation({ summary: 'Submit attempt (batch legacy)' })
  submit(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: SubmitAttemptDto,
  ) {
    return this.service.submitAttempt(
      user.userId,
      id,
      dto.answers,
      dto.timeSec ?? 0,
    );
  }

  @Get('attempts/:id/certificate')
  @ApiOperation({ summary: 'Certificate data for a winning attempt (#56)' })
  certificate(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getCertificate(user.userId, id);
  }
}
