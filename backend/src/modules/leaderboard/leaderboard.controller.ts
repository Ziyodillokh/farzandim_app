import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { LeaderboardService } from './leaderboard.service';
import { LeaderboardQueryDto, LeaderboardPeriod } from './dto/leaderboard-query.dto';

@ApiTags('Leaderboard')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard)
@Controller('leaderboard')
export class LeaderboardController {
  constructor(private readonly service: LeaderboardService) {}

  @Get()
  @ApiOperation({
    summary:
      'XP reyting — period (weekly/monthly/all) + viloyat + pagination + joriy bola ("Siz")',
  })
  @ApiResponse({ status: 200, description: 'Reyting sahifasi' })
  async get(@Query() query: LeaderboardQueryDto) {
    return this.service.getLeaderboard({
      period: query.period ?? LeaderboardPeriod.all,
      region: query.region,
      page: query.page ?? 1,
      limit: query.limit ?? 15,
      childId: query.childId,
    });
  }
}
