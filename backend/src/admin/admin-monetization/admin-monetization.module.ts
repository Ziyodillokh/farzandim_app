import { Module } from '@nestjs/common';
import { AdminMonetizationController } from './admin-monetization.controller';
import { AdminMonetizationService } from './admin-monetization.service';

@Module({
  controllers: [AdminMonetizationController],
  providers: [AdminMonetizationService],
})
export class AdminMonetizationModule {}
