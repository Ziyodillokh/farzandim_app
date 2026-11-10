// Parvoz School — maktab uchun Growth (`/api/school/learning`,
// `/api/child/school/assignments`): sinf faolligi, qiziqishlar, materiallar,
// topshiriqlar + ertangi topshiriq eslatmasi (cron). Ma'lumot — ota-ona bog'lagan bolalarning Daily Learning'i.

import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { NotificationPrefsModule } from '../../common/notification-prefs/notification-prefs.module';
import { HomeworkModule } from '../homework/homework.module';
import { SchoolCoreModule } from '../school-core.module';
import { HomeworkReminderService } from './homework-reminder.service';
import { SchoolLearningChildService } from './school-learning-child.service';
import { SchoolLearningChildController, SchoolLearningController } from './school-learning.controller';
import { SchoolLearningService } from './school-learning.service';
import { SchoolMaterialsService } from './school-materials.service';

@Module({
  imports: [SchoolCoreModule, HomeworkModule, FcmModule, NotificationPrefsModule],
  controllers: [SchoolLearningController, SchoolLearningChildController],
  providers: [SchoolLearningService, SchoolLearningChildService, SchoolMaterialsService, HomeworkReminderService],
  exports: [SchoolLearningService],
})
export class SchoolLearningModule {}
