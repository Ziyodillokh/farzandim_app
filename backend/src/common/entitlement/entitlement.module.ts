import { Global, Module } from '@nestjs/common';
import { EntitlementController } from './entitlement.controller';
import { EntitlementGuard } from './entitlement.guard';
import { EntitlementService } from './entitlement.service';

/**
 * Tarif (entitlement) — butun backend feature-gating markazi. @Global: har qanday
 * modul EntitlementService/EntitlementGuard'ni qo'shimcha import'siz ishlatadi.
 * (PrismaService @Global orqali keladi.)
 */
@Global()
@Module({
  controllers: [EntitlementController],
  providers: [EntitlementService, EntitlementGuard],
  exports: [EntitlementService, EntitlementGuard],
})
export class EntitlementModule {}
