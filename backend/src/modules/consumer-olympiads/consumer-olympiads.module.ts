import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { GamificationModule } from '../gamification/gamification.module';
import { ConsumerOlympiadsController } from './consumer-olympiads.controller';
import { ConsumerOlympiadsService } from './consumer-olympiads.service';

@Module({
  imports: [DatabaseModule, GamificationModule],
  controllers: [ConsumerOlympiadsController],
  providers: [ConsumerOlympiadsService],
  exports: [ConsumerOlympiadsService],
})
export class ConsumerOlympiadsModule {}
