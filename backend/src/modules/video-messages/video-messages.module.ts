import { Module } from '@nestjs/common';
import { NotificationPrefsModule } from '../../common/notification-prefs/notification-prefs.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { VideoMessagesController } from './video-messages.controller';
import { VideoMessagesService } from './video-messages.service';

@Module({
  imports: [NotificationPrefsModule, RealtimeModule],
  controllers: [VideoMessagesController],
  providers: [VideoMessagesService],
  exports: [VideoMessagesService],
})
export class VideoMessagesModule {}
