import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { GamificationModule } from '../gamification/gamification.module';
import { LearningInsightsService } from './learning-insights.service';
import { LearningParentController } from './learning-parent.controller';
import { LearningController } from './learning.controller';
import { LearningService } from './learning.service';

@Module({
  imports: [DatabaseModule, GamificationModule, FcmModule],
  controllers: [LearningController, LearningParentController],
  providers: [LearningService, LearningInsightsService],
  exports: [LearningService, LearningInsightsService],
})
export class LearningModule {}
