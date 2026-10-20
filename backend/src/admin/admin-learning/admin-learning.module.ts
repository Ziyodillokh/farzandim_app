import { Module } from '@nestjs/common';
import { AdminLearningController } from './admin-learning.controller';
import { AdminLearningService } from './admin-learning.service';

@Module({
  controllers: [AdminLearningController],
  providers: [AdminLearningService],
})
export class AdminLearningModule {}
