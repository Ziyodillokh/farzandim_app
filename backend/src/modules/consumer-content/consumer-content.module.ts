import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { StorageModule } from '../../common/storage/storage.module';
import { GamificationModule } from '../gamification/gamification.module';
import { ConsumerContentController } from './consumer-content.controller';
import { ConsumerContentService } from './consumer-content.service';

@Module({
  imports: [DatabaseModule, StorageModule, GamificationModule],
  controllers: [ConsumerContentController],
  providers: [ConsumerContentService],
  exports: [ConsumerContentService],
})
export class ConsumerContentModule {}
