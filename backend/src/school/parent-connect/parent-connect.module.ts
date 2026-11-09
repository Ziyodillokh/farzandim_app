// Ota-ona ↔ maktab aloqasi (`/api/parent/school/contacts|threads|students/:id/overview`,
// `/api/school/parent-threads/*`): kontaktlar, maxfiy yozishmalar va farzand statistikasi.

import { Module } from '@nestjs/common';
import { CommsModule } from '../comms/comms.module';
import { SchoolCoreModule } from '../school-core.module';
import { ParentConnectController } from './parent-connect.controller';
import { ParentOverviewService } from './parent-overview.service';
import { ParentThreadsService } from './parent-threads.service';
import { StaffParentThreadsController } from './staff-parent-threads.controller';
import { StaffThreadsService } from './staff-threads.service';

@Module({
  imports: [SchoolCoreModule, CommsModule],
  controllers: [ParentConnectController, StaffParentThreadsController],
  providers: [ParentThreadsService, StaffThreadsService, ParentOverviewService],
})
export class ParentConnectModule {}
