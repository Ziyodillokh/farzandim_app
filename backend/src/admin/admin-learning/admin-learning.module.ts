import { Module } from '@nestjs/common';
import { AdminLearningTopicsService } from './admin-learning-topics.service';
import { AdminLearningController } from './admin-learning.controller';
import { AdminLearningService } from './admin-learning.service';

@Module({
  controllers: [AdminLearningController],
  providers: [AdminLearningService, AdminLearningTopicsService],
})
export class AdminLearningModule {}
