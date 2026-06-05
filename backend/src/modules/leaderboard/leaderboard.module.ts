import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardService } from './leaderboard.service';

@Module({
  imports: [DatabaseModule],
  controllers: [LeaderboardController],
  providers: [LeaderboardService],
})
export class LeaderboardModule {}
