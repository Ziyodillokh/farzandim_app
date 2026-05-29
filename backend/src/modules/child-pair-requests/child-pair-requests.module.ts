import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { ChildPairRequestsController } from './child-pair-requests.controller';
import { ChildPairRequestsService } from './child-pair-requests.service';

@Module({
  imports: [DatabaseModule, AuditModule, RealtimeModule],
  controllers: [ChildPairRequestsController],
  providers: [ChildPairRequestsService],
  exports: [ChildPairRequestsService],
})
export class ChildPairRequestsModule {}
