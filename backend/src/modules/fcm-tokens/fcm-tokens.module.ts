import { Module } from '@nestjs/common';
import { FcmTokensController } from './fcm-tokens.controller';
import { FcmTokensService } from './fcm-tokens.service';

@Module({
  controllers: [FcmTokensController],
  providers: [FcmTokensService],
  exports: [FcmTokensService],
})
export class FcmTokensModule {}
