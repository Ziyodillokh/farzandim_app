import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { BadgesService } from './badges/badges.service';
import { GamificationController } from './gamification.controller';
import { GamificationService } from './gamification.service';
import { DonLedgerService } from './ledger/don-ledger.service';

@Module({
  imports: [DatabaseModule, AuditModule, RealtimeModule],
  controllers: [GamificationController],
  providers: [GamificationService, BadgesService, DonLedgerService],
  exports: [GamificationService],
})
export class GamificationModule {}
