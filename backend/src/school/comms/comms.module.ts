// Parvoz School — Comms moduli (`/api/school/comms/*`, `/api/parent/school/*`):
// e'lonlar, Smart Reminder, to'lov eslatmalari, tekshiruv so'rovlari, push va
// har daqiqalik yuborish (cron).

import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SchoolCoreModule } from '../school-core.module';
import { AnnouncementDeliveryService } from './announcement-delivery.service';
import { AnnouncementSendService } from './announcement-send.service';
import { AnnouncementsService } from './announcements.service';
import { CommsAnnouncementsController } from './comms-announcements.controller';
import { CommsDispatcherService } from './comms-dispatcher.service';
import { CommsOverviewService } from './comms-overview.service';
import { CommsPaymentsController, CommsVerificationsController } from './comms-payments.controller';
import { CommsPushService } from './comms-push.service';
import { CommsRemindersController } from './comms-reminders.controller';
import { CommsController } from './comms.controller';
import { ParentSchoolCommsController } from './parent-school-comms.controller';
import { ParentSchoolCommsService } from './parent-school-comms.service';
import { PaymentUpdatesService } from './payment-updates.service';
import { PaymentsService } from './payments.service';
import { RemindersService } from './reminders.service';
import { VerificationsService } from './verifications.service';

@Module({
  imports: [SchoolCoreModule, FcmModule],
  controllers: [
    CommsController,
    CommsAnnouncementsController,
    CommsRemindersController,
    CommsPaymentsController,
    CommsVerificationsController,
    ParentSchoolCommsController,
  ],
  providers: [
    CommsPushService,
    AnnouncementDeliveryService,
    AnnouncementsService,
    AnnouncementSendService,
    RemindersService,
    PaymentsService,
    PaymentUpdatesService,
    VerificationsService,
    CommsOverviewService,
    CommsDispatcherService,
    ParentSchoolCommsService,
  ],
})
export class CommsModule {}
