import { Module } from '@nestjs/common';
import { NotificationPrefsModule } from '../../common/notification-prefs/notification-prefs.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { VoiceMessagesController } from './voice-messages.controller';
import { VoiceMessagesService } from './voice-messages.service';

@Module({
  imports: [NotificationPrefsModule, RealtimeModule],
  controllers: [VoiceMessagesController],
  providers: [VoiceMessagesService],
  exports: [VoiceMessagesService],
})
export class VoiceMessagesModule {}
