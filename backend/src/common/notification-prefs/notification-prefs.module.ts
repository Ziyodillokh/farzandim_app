import { Module } from '@nestjs/common';
import { FcmModule } from '../fcm/fcm.module';
import { ChildPushDedupeService } from './child-push-dedupe.service';
import { FamilyMessagePushService } from './family-message-push.service';
import { NotificationPrefsService } from './notification-prefs.service';

/** Bola push'lari uchun umumiy: sozlamalarni o'qish, oila xabari push'i va "bir marta" kafolati. PrismaService global. */
@Module({
  imports: [FcmModule],
  providers: [NotificationPrefsService, FamilyMessagePushService, ChildPushDedupeService],
  exports: [NotificationPrefsService, FamilyMessagePushService, ChildPushDedupeService],
})
export class NotificationPrefsModule {}
