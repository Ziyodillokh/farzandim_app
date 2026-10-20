// Parvoz School — bosh sahifa, bildirishnomalar, hisobotlar, qidiruv:
// faqat o'qish; raqamlar tegishli modul servislaridan (sahifalar bilan mos).

import { Module } from '@nestjs/common';
import { AttendanceModule } from '../attendance/attendance.module';
import { CareModule } from '../care/care.module';
import { SchoolLearningModule } from '../learning/school-learning.module';
import { SchoolCoreModule } from '../school-core.module';
import { SchoolModeModule } from '../school-mode/school-mode.module';
import { StudentsModule } from '../students/students.module';
import { DashboardService } from './dashboard.service';
import { InsightsController } from './insights.controller';
import { NotificationsService } from './notifications.service';
import { ReportsService } from './reports.service';
import { SearchService } from './search.service';

@Module({
  imports: [SchoolCoreModule, AttendanceModule, CareModule, SchoolModeModule, StudentsModule, SchoolLearningModule],
  controllers: [InsightsController],
  providers: [DashboardService, NotificationsService, ReportsService, SearchService],
})
export class InsightsModule {}
