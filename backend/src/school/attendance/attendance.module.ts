// Parvoz School — Attendance moduli (`/api/school/attendance/*`, kiosk,
// Parvoz Growth QR kirishi `/api/child/school/*`, Parvoz Parents `/api/parent/school/*`).

import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SchoolCoreModule } from '../school-core.module';
import { AttendanceAbsenceCron } from './attendance-absence.cron';
import { AttendanceArrivalService } from './attendance-arrival.service';
import { AttendanceBoardService } from './attendance-board.service';
import { AttendanceChildService } from './attendance-child.service';
import { AttendanceChildController, AttendanceParentController } from './attendance-consumer.controller';
import { AttendanceEarlyExitService } from './attendance-early-exit.service';
import { AttendanceHistoryController } from './attendance-history.controller';
import { AttendanceKioskController } from './attendance-kiosk.controller';
import { KioskTokenService } from './attendance-kiosk-token';
import { AttendanceKioskService } from './attendance-kiosk.service';
import { AttendanceMarkingService } from './attendance-marking.service';
import { AttendanceNotifyService } from './attendance-notify.service';
import { AttendanceParentService } from './attendance-parent.service';
import { AttendanceReportsService } from './attendance-reports.service';
import { AttendanceClock } from './attendance-time';
import { AttendanceController } from './attendance.controller';

@Module({
  imports: [SchoolCoreModule, FcmModule],
  controllers: [
    AttendanceController,
    AttendanceKioskController,
    AttendanceHistoryController,
    AttendanceChildController,
    AttendanceParentController,
  ],
  providers: [
    AttendanceClock,
    KioskTokenService,
    AttendanceNotifyService,
    AttendanceArrivalService,
    AttendanceBoardService,
    AttendanceMarkingService,
    AttendanceKioskService,
    AttendanceEarlyExitService,
    AttendanceReportsService,
    AttendanceChildService,
    AttendanceParentService,
    AttendanceAbsenceCron,
  ],
})
export class AttendanceModule {}
