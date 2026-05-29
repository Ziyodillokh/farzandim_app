import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { VoiceMessagesController } from './voice-messages.controller';
import { VoiceMessagesService } from './voice-messages.service';

@Module({
  imports: [FcmModule, RealtimeModule],
  controllers: [VoiceMessagesController],
  providers: [VoiceMessagesService],
  exports: [VoiceMessagesService],
})
export class VoiceMessagesModule {}
