import { Module } from '@nestjs/common';
import { AdminSecurityController } from './admin-security.controller';

// SecuritySettingsService global modulda (common/security) — bu yerda faqat
// controller. Guard ham o'sha global service'dan foydalanadi.
@Module({
  controllers: [AdminSecurityController],
})
export class AdminSecurityModule {}
