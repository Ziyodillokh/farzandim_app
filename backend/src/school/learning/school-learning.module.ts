// Parvoz School — maktab uchun Growth (`/api/school/learning`,
// `/api/child/school/assignments`): sinf faolligi, qiziqishlar, materiallar,
// topshiriqlar. Ma'lumot — ota-ona bog'lagan bolalarning Daily Learning'i.

import { Module } from '@nestjs/common';
import { HomeworkModule } from '../homework/homework.module';
import { SchoolCoreModule } from '../school-core.module';
import { SchoolLearningChildService } from './school-learning-child.service';
import { SchoolLearningChildController, SchoolLearningController } from './school-learning.controller';
import { SchoolLearningService } from './school-learning.service';

@Module({
  imports: [SchoolCoreModule, HomeworkModule],
  controllers: [SchoolLearningController, SchoolLearningChildController],
  providers: [SchoolLearningService, SchoolLearningChildService],
  exports: [SchoolLearningService],
})
export class SchoolLearningModule {}
