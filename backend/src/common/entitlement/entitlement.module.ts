import { Global, Module } from '@nestjs/common';
import { EntitlementController } from './entitlement.controller';
import { EntitlementGuard } from './entitlement.guard';
import { EntitlementService } from './entitlement.service';
import { PaidTierGuard } from './paid-tier.guard';

/**
 * Tarif (entitlement) — butun backend feature-gating markazi. @Global: har qanday
 * modul EntitlementService/EntitlementGuard/PaidTierGuard'ni qo'shimcha import'siz
 * ishlatadi. (PrismaService @Global orqali keladi.)
 */
@Global()
@Module({
  controllers: [EntitlementController],
  providers: [EntitlementService, EntitlementGuard, PaidTierGuard],
  exports: [EntitlementService, EntitlementGuard, PaidTierGuard],
})
export class EntitlementModule {}
