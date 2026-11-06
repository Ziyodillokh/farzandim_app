import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { GamificationModule } from '../gamification/gamification.module';
import { IqParentController } from './iq-parent.controller';
import { IqController } from './iq.controller';
import { IqService } from './iq.service';

@Module({
  imports: [DatabaseModule, GamificationModule],
  controllers: [IqController, IqParentController],
  providers: [IqService],
  exports: [IqService],
})
export class IqModule {}
