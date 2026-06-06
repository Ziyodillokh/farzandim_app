import { Global, Module } from '@nestjs/common';
import { SecuritySettingsService } from './security-settings.service';

// @Global — guard (AdminJwtAuthGuard) va admin-security controller ikkalasi
// ham foydalanadi. PrismaService allaqachon global.
@Global()
@Module({
  providers: [SecuritySettingsService],
  exports: [SecuritySettingsService],
})
export class SecuritySettingsModule {}
