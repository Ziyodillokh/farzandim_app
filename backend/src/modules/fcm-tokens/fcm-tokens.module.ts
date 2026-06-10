import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { FcmTokensController } from './fcm-tokens.controller';
import { FcmTokensService } from './fcm-tokens.service';

@Module({
  imports: [FcmModule],
  controllers: [FcmTokensController],
  providers: [FcmTokensService],
  exports: [FcmTokensService],
})
export class FcmTokensModule {}
