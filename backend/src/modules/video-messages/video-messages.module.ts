import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { VideoMessagesController } from './video-messages.controller';
import { VideoMessagesService } from './video-messages.service';

@Module({
  imports: [FcmModule, RealtimeModule],
  controllers: [VideoMessagesController],
  providers: [VideoMessagesService],
  exports: [VideoMessagesService],
})
export class VideoMessagesModule {}
