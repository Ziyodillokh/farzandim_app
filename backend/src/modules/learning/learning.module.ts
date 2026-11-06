import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { GamificationModule } from '../gamification/gamification.module';
import { LearningInsightsService } from './learning-insights.service';
import { LearningPickService } from './learning-pick.service';
import { LearningParentController } from './learning-parent.controller';
import { LearningTopicsService } from './learning-topics.service';
import { LearningOfflineService } from './learning-offline.service';
import { LearningWeeklyService } from './learning-weekly.service';
import { LearningController } from './learning.controller';
import { LearningService } from './learning.service';

@Module({
  imports: [DatabaseModule, GamificationModule, FcmModule],
  controllers: [LearningController, LearningParentController],
  providers: [
    LearningService,
    LearningInsightsService,
    LearningTopicsService,
    LearningPickService,
    LearningWeeklyService,
    LearningOfflineService,
  ],
  exports: [LearningService, LearningInsightsService],
})
export class LearningModule {}
